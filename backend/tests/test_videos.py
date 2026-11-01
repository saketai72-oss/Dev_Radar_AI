"""The /videos routes: on-demand render and public MP4 serving."""

import json
from pathlib import Path

import httpx
import pytest

from app.core.config import settings
from app.models import GeneratedVideo, Repo, UserRepo
from app.services import video_client

URL = "/api/v1/videos"

RESULT = {"path": "/data/videos/whatever.mp4", "duration_seconds": 12.4, "size_bytes": 1024}


def assert_error(response, status_code: int, code: str):
    assert response.status_code == status_code
    body = response.json()
    assert set(body) == {"error"}
    assert body["error"]["code"] == code


@pytest.fixture(autouse=True)
def video_dir(tmp_path, monkeypatch) -> Path:
    """Point the shared volume at a temp dir, so no test touches /data/videos."""
    monkeypatch.setattr(settings, "video_output_dir", str(tmp_path))
    return tmp_path


def rendered(request: httpx.Request) -> httpx.Response:
    """Answer like the real engine: 200 plus the MP4 dropped where we look for it."""
    job_id = json.loads(request.content)["job_id"]
    (Path(settings.video_output_dir) / f"{job_id}.mp4").write_bytes(b"fake mp4 bytes")
    return httpx.Response(200, json=RESULT)


@pytest.fixture
def roadmap(db, user) -> list[UserRepo]:
    """Two repos in the user's roadmap, with language and stars."""
    rows = []
    for n, (language, stars, status) in enumerate(
        [("Go", 900, "learning"), ("Python", 10, "used")], start=1
    ):
        repo = Repo(
            github_id=2000 + n,
            full_name=f"owner{n}/repo{n}",
            owner=f"owner{n}",
            name=f"repo{n}",
            html_url=f"https://github.com/owner{n}/repo{n}",
            language=language,
            stars=stars,
        )
        db.add(repo)
        db.commit()
        row = UserRepo(user_id=user.id, repo_id=repo.id, status=status)
        db.add(row)
        db.commit()
        rows.append(row)
    return rows


@pytest.fixture
def engine(monkeypatch):
    monkeypatch.setattr(settings, "video_engine_url", "http://video-engine:9000")

    def install(handler):
        transport = httpx.MockTransport(handler)
        monkeypatch.setattr(
            video_client,
            "_make_client",
            lambda: httpx.Client(transport=transport, base_url="http://video-engine:9000"),
        )

    return install


def test_post_roadmap_renders_and_returns_a_relative_url(client, auth_headers, db, roadmap, engine):
    engine(rendered)

    response = client.post(f"{URL}/roadmap", headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert body["url"] == f"{URL}/{body['job_id']}"
    assert body["url"].startswith("/")
    assert body["duration_seconds"] == pytest.approx(12.4)
    assert body["size_bytes"] == 1024

    saved = db.query(GeneratedVideo).filter_by(job_id=body["job_id"]).one()
    assert saved.duration_seconds == pytest.approx(12.4)
    assert saved.video_type == "roadmap"


def test_post_roadmap_requires_auth(client, roadmap, engine):
    engine(lambda request: httpx.Response(200, json=RESULT))

    assert client.post(f"{URL}/roadmap").status_code == 401


def test_post_roadmap_with_empty_roadmap_is_400(client, auth_headers):
    response = client.post(f"{URL}/roadmap", headers=auth_headers)

    assert_error(response, 400, "BAD_REQUEST")


def test_post_roadmap_engine_timeout_is_504(client, auth_headers, roadmap, engine):
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("too slow", request=request)

    engine(handler)

    assert_error(client.post(f"{URL}/roadmap", headers=auth_headers), 504, "UPSTREAM_TIMEOUT")


def test_post_roadmap_engine_error_is_502(client, auth_headers, roadmap, engine):
    engine(lambda request: httpx.Response(500, json={"detail": "boom"}))

    assert_error(client.post(f"{URL}/roadmap", headers=auth_headers), 502, "UPSTREAM_ERROR")


def test_post_roadmap_releases_the_db_connection_while_rendering(client, auth_headers, db, roadmap, engine):
    """A render blocks for 30s-1min. Holding a pooled connection that whole time
    can exhaust QueuePool and 500 every unrelated endpoint, so the transaction
    must be closed before the engine is called."""
    seen = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["in_transaction"] = db.in_transaction()
        return rendered(request)

    engine(handler)

    assert client.post(f"{URL}/roadmap", headers=auth_headers).status_code == 200
    assert seen["in_transaction"] is False


def test_post_roadmap_502_when_the_mp4_is_not_in_the_shared_volume(client, auth_headers, roadmap, engine, video_dir):
    """A volume/path mismatch would otherwise answer 200 with a URL that 404s forever."""
    engine(lambda request: httpx.Response(200, json=RESULT))

    assert_error(client.post(f"{URL}/roadmap", headers=auth_headers), 502, "UPSTREAM_ERROR")


def test_get_serves_file_without_auth(client, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "video_output_dir", str(tmp_path))
    (tmp_path / "jobabc.mp4").write_bytes(b"fake mp4 bytes")

    response = client.get(f"{URL}/jobabc")

    assert response.status_code == 200
    assert response.headers["content-type"] == "video/mp4"
    assert response.content == b"fake mp4 bytes"


def test_get_unknown_job_is_404(client, tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "video_output_dir", str(tmp_path))

    assert_error(client.get(f"{URL}/missing"), 404, "NOT_FOUND")


@pytest.mark.parametrize("job_id", ["x" * 65, "bad.id"])
def test_get_malformed_job_id_is_404(client, tmp_path, monkeypatch, job_id):
    monkeypatch.setattr(settings, "video_output_dir", str(tmp_path))
    # A file that WOULD match if the guard were missing.
    (tmp_path / f"{job_id}.mp4").write_bytes(b"nope")

    assert_error(client.get(f"{URL}/{job_id}"), 404, "NOT_FOUND")


def test_post_repo_video_renders_and_returns_relative_url(client, auth_headers, db, engine):
    engine(rendered)
    repo = Repo(
        github_id=9999,
        full_name="tiangolo/fastapi",
        owner="tiangolo",
        name="fastapi",
        description="FastAPI framework, high performance, easy to learn.",
        html_url="https://github.com/tiangolo/fastapi",
        language="Python",
        stars=75000,
        forks=6000,
        topics=["fastapi", "python", "pydantic"],
        readme="# FastAPI\n\n```bash\npip install fastapi\n```\n",
    )
    db.add(repo)
    db.commit()

    response = client.post(f"{URL}/repos/{repo.id}", headers=auth_headers)

    assert response.status_code == 200
    body = response.json()
    assert body["url"] == f"{URL}/{body['job_id']}"
    assert body["duration_seconds"] == pytest.approx(12.4)
    assert body["size_bytes"] == 1024

    saved = db.query(GeneratedVideo).filter_by(job_id=body["job_id"]).one()
    assert saved.duration_seconds == pytest.approx(12.4)
    assert saved.video_type == "repo"
    assert saved.repo_id == repo.id


def test_post_repo_video_requires_auth(client, engine):
    engine(lambda request: httpx.Response(200, json=RESULT))
    assert client.post(f"{URL}/repos/1").status_code == 401


def test_post_repo_video_unknown_repo_is_404(client, auth_headers):
    assert_error(client.post(f"{URL}/repos/999999", headers=auth_headers), 404, "NOT_FOUND")


def test_video_specs_normalize_brand_phonetics():
    from app.services.video_spec import normalize_narration, build_repo_video_spec
    assert normalize_narration("Khám phá trên Dev Radar AI") == "Khám phá trên đép ra đa ây ai"
    assert normalize_narration("Chào mừng đến với Dev Radar") == "Chào mừng đến với đép ra đa ây ai"

    repo = Repo(github_id=1, full_name="user/tool", owner="user", name="tool", html_url="https://github.com/user/tool", stars=10)
    spec = build_repo_video_spec("job1", repo)
    assert "đép ra đa ây ai" in spec["slides"][0]["narration"]
    assert "đép ra đa ây ai" in spec["slides"][-1]["narration"]
    assert spec["slides"][-1]["title"] == "Khám phá trên Dev Radar AI"


# --- Caching tests ---

def test_get_roadmap_video_requires_auth(client):
    assert client.get(f"{URL}/roadmap").status_code == 401


def test_get_roadmap_video_404_when_no_video(client, auth_headers):
    assert_error(client.get(f"{URL}/roadmap", headers=auth_headers), 404, "NOT_FOUND")


def test_get_roadmap_video_404_when_file_missing_on_disk(client, auth_headers, db, user):
    video = GeneratedVideo(
        job_id="job_missing_file",
        user_id=user.id,
        video_type="roadmap",
        duration_seconds=10.0,
        size_bytes=500,
    )
    db.add(video)
    db.commit()

    assert_error(client.get(f"{URL}/roadmap", headers=auth_headers), 404, "NOT_FOUND")


def test_get_roadmap_video_200_when_cached(client, auth_headers, db, user, video_dir):
    job_id = "cached_roadmap_job"
    (video_dir / f"{job_id}.mp4").write_bytes(b"cached video")
    video = GeneratedVideo(
        job_id=job_id,
        user_id=user.id,
        video_type="roadmap",
        duration_seconds=15.0,
        size_bytes=2048,
    )
    db.add(video)
    db.commit()

    response = client.get(f"{URL}/roadmap", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["job_id"] == job_id
    assert body["url"] == f"{URL}/{job_id}"
    assert body["duration_seconds"] == 15.0
    assert body["size_bytes"] == 2048


def test_post_roadmap_returns_cached_when_not_force(client, auth_headers, db, user, video_dir, engine):
    job_id = "cached_job_123"
    (video_dir / f"{job_id}.mp4").write_bytes(b"cached video")
    db.add(
        GeneratedVideo(
            job_id=job_id,
            user_id=user.id,
            video_type="roadmap",
            duration_seconds=12.0,
            size_bytes=1000,
        )
    )
    db.commit()

    called = False

    def fail_handler(request: httpx.Request) -> httpx.Response:
        nonlocal called
        called = True
        return httpx.Response(500)

    engine(fail_handler)

    # force defaults to False: returns cached video without calling engine
    res = client.post(f"{URL}/roadmap", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["job_id"] == job_id
    assert not called

    # explicit force=False
    res2 = client.post(f"{URL}/roadmap?force=false", headers=auth_headers)
    assert res2.status_code == 200
    assert res2.json()["job_id"] == job_id
    assert not called


def test_post_roadmap_force_true_rerenders(client, auth_headers, db, user, roadmap, video_dir, engine):
    job_id = "old_cached_job"
    (video_dir / f"{job_id}.mp4").write_bytes(b"old cached video")
    db.add(
        GeneratedVideo(
            job_id=job_id,
            user_id=user.id,
            video_type="roadmap",
            duration_seconds=12.0,
            size_bytes=1000,
        )
    )
    db.commit()

    engine(rendered)

    res = client.post(f"{URL}/roadmap?force=true", headers=auth_headers)
    assert res.status_code == 200
    body = res.json()
    assert body["job_id"] != job_id
    assert body["job_id"] is not None


def test_get_repo_video_requires_auth(client):
    assert client.get(f"{URL}/repos/1").status_code == 401


def test_get_repo_video_404_when_no_video(client, auth_headers):
    assert_error(client.get(f"{URL}/repos/999", headers=auth_headers), 404, "NOT_FOUND")


def test_get_repo_video_404_when_file_missing_on_disk(client, auth_headers, db, user):
    repo = Repo(
        github_id=4444,
        full_name="org/file-missing",
        owner="org",
        name="file-missing",
        html_url="https://github.com/org/file-missing",
        stars=1,
    )
    db.add(repo)
    db.commit()

    job_id = "repo_video_no_file"
    db.add(
        GeneratedVideo(
            job_id=job_id,
            user_id=user.id,
            video_type="repo",
            repo_id=repo.id,
            duration_seconds=10.0,
            size_bytes=500,
        )
    )
    db.commit()

    assert_error(client.get(f"{URL}/repos/{repo.id}", headers=auth_headers), 404, "NOT_FOUND")


def test_get_repo_video_200_when_cached(client, auth_headers, db, user, video_dir):
    repo = Repo(
        github_id=5555,
        full_name="org/test",
        owner="org",
        name="test",
        html_url="https://github.com/org/test",
        stars=10,
    )
    db.add(repo)
    db.commit()

    job_id = "cached_repo_job"
    (video_dir / f"{job_id}.mp4").write_bytes(b"cached repo video")
    db.add(
        GeneratedVideo(
            job_id=job_id,
            user_id=user.id,
            video_type="repo",
            repo_id=repo.id,
            duration_seconds=18.5,
            size_bytes=4096,
        )
    )
    db.commit()

    response = client.get(f"{URL}/repos/{repo.id}", headers=auth_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["job_id"] == job_id
    assert body["url"] == f"{URL}/{job_id}"
    assert body["duration_seconds"] == 18.5
    assert body["size_bytes"] == 4096


def test_post_repo_video_returns_cached_when_not_force(client, auth_headers, db, user, video_dir, engine):
    repo = Repo(
        github_id=6666,
        full_name="org/cache-test",
        owner="org",
        name="cache-test",
        html_url="https://github.com/org/cache-test",
        stars=50,
    )
    db.add(repo)
    db.commit()

    job_id = "cached_repo_video_job"
    (video_dir / f"{job_id}.mp4").write_bytes(b"cached video")
    db.add(
        GeneratedVideo(
            job_id=job_id,
            user_id=user.id,
            video_type="repo",
            repo_id=repo.id,
            duration_seconds=20.0,
            size_bytes=5000,
        )
    )
    db.commit()

    called = False

    def fail_handler(request: httpx.Request) -> httpx.Response:
        nonlocal called
        called = True
        return httpx.Response(500)

    engine(fail_handler)

    res = client.post(f"{URL}/repos/{repo.id}", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["job_id"] == job_id
    assert not called

    res2 = client.post(f"{URL}/repos/{repo.id}?force=false", headers=auth_headers)
    assert res2.status_code == 200
    assert res2.json()["job_id"] == job_id
    assert not called


def test_post_repo_video_force_true_rerenders(client, auth_headers, db, user, video_dir, engine):
    repo = Repo(
        github_id=7777,
        full_name="org/force-test",
        owner="org",
        name="force-test",
        html_url="https://github.com/org/force-test",
        stars=100,
    )
    db.add(repo)
    db.commit()

    job_id = "old_repo_job"
    (video_dir / f"{job_id}.mp4").write_bytes(b"old video")
    db.add(
        GeneratedVideo(
            job_id=job_id,
            user_id=user.id,
            video_type="repo",
            repo_id=repo.id,
            duration_seconds=20.0,
            size_bytes=5000,
        )
    )
    db.commit()

    engine(rendered)

    res = client.post(f"{URL}/repos/{repo.id}?force=true", headers=auth_headers)
    assert res.status_code == 200
    body = res.json()
    assert body["job_id"] != job_id
