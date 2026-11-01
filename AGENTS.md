# AGENTS.md – Hướng dẫn cho AI agent: setup và chạy đủ tính năng DevRadar AI

File này viết cho **AI agent** (Claude Code, Codex, Cursor, Copilot…) đang giúp một **người mới** cài và chạy dự án.
Làm lần lượt từng mục. Mỗi bước có **lệnh** và **cách kiểm tra**: chỉ sang bước sau khi kiểm tra đạt.

Tài liệu cho người đọc: [README.md](README.md) (tổng quan), [CONTRIBUTING.md](CONTRIBUTING.md) (quy trình nhóm),
[backend/README.md](backend/README.md), [mobile/README.md](mobile/README.md), [ai-engine/README.md](ai-engine/README.md).

---

## 1. Bản đồ dự án

```
Flutter app ──REST──▶ backend (FastAPI) ──▶ ai-engine (FastAPI) ──▶ ollama (LLM qwen2.5:7b, GPU)
 (mobile/)              │  JWT, cron          │  embedding + RAG
                        │                     ▼
                        ├──────────▶ db: PostgreSQL 16 + pgvector
                        └──────────▶ video-engine (Piper TTS + FFmpeg)        GitHub API ◀── cron
```

| Service (docker compose) | Vai trò | Cổng trên máy | Bắt buộc? |
|---|---|---|---|
| `db` | PostgreSQL 16 + pgvector | `DB_PORT` (mặc định 5432) | Có |
| `backend` | REST API, cron, cổng duy nhất app gọi vào | `BACKEND_PORT` (mặc định 8080) | Có |
| `video-engine` | Dựng video 9:16 có giọng đọc | không mở ra ngoài (nội bộ 9000) | Cho tính năng video |
| `ai-engine` | Tóm tắt README, index, chat RAG | không mở ra ngoài (nội bộ 8000) | Cho AI thật |
| `ollama` + `ollama-pull` | Chạy LLM, tải model lần đầu | không mở ra ngoài | Cho AI thật |

App **chỉ** gọi backend. Backend tự gọi các service còn lại qua mạng Docker.

---

## 2. Kiểm tra máy trước khi cài

| Cần | Lệnh kiểm tra | Ghi chú |
|---|---|---|
| Docker Desktop đang chạy | `docker info` | Lỗi `dockerDesktopLinuxEngine` = Docker chưa bật: mở Docker Desktop rồi chờ ~30 s |
| Flutter SDK (Dart ≥ 3.11) | `flutter --version` | Nếu không có trong PATH, tìm `flutter.bat` (vd. `E:\tools\flutter\bin`) và gọi bằng đường dẫn đầy đủ |
| Android SDK + emulator | `flutter emulators`, `adb devices` | Nếu `adb` không có trong PATH: đặt `ANDROID_HOME` trỏ tới SDK |
| GPU NVIDIA (chỉ cho AI thật) | `nvidia-smi` | Không có GPU vẫn chạy được: dùng chế độ CPU hoặc AI dự phòng (mục 3.2) |
| Dung lượng trống | – | ~10 GB nếu bật AI thật (image Ollama ~5 GB + model ~4.4 GB) |

**Windows:** shell mặc định có thể là PowerShell 5.1: không có `&&`, và in chữ tiếng Việt từ API bị vỡ (dữ liệu vẫn đúng).
Dùng Git Bash cho các lệnh dưới đây, hoặc đổi cú pháp cho PowerShell.

---

## 3. Setup từng bước

### 3.1. File `.env`

```bash
cp .env.example .env          # PowerShell: Copy-Item .env.example .env
```

Sửa trong `.env`:

| Biến | Làm gì |
|---|---|
| `JWT_SECRET` | Chuỗi ngẫu nhiên ≥ 32 ký tự |
| `DB_PORT`, `BACKEND_PORT` | Đổi nếu máy đã có app dùng 5432 / 8080 (vd. `5433`, `8081`). **Mọi lệnh dưới đây dùng `$PORT` = giá trị `BACKEND_PORT`** |
| `GITHUB_TOKEN` | Nên có (tăng giới hạn GitHub API, cron lấy repo và README). Không bắt buộc |
| `AI_ENGINE_URL` | Có AI thật: giữ `http://ai-engine:8000`. **Không bật ai-engine: để trống `AI_ENGINE_URL=`** (xem cảnh báo ở 3.2) |
| `VIDEO_ENGINE_URL` | Giữ `http://video-engine:9000`. Để trống = tắt tính năng video (backend trả 503) |
| `GOOGLE_CLIENT_IDS`, `GITHUB_CLIENT_*` | Tuỳ chọn, cho đăng nhập Google/GitHub – xem [backend/docs/OAUTH_LOGIN.md](backend/docs/OAUTH_LOGIN.md) |

Không bao giờ commit `.env`.

### 3.2. Bật server – chọn một chế độ

| Chế độ | Khi nào | Lệnh |
|---|---|---|
| **A. Cơ bản** | Không cần AI thật | `docker compose up -d --build db backend video-engine` và đặt `AI_ENGINE_URL=` trong `.env` |
| **B. AI thật – GPU** (khuyên dùng nếu có NVIDIA) | Có `nvidia-smi` | `docker compose up -d --build` |
| **C. AI thật – CPU** | Không có GPU, chấp nhận chậm | `docker compose -f docker-compose.yml -f docker-compose.cpu.yml up -d --build` (nên đặt `OLLAMA_MODEL=qwen2.5:3b`) |

> ⚠️ **Cảnh báo quan trọng:** nếu `AI_ENGINE_URL` có giá trị mà container `ai-engine` **không chạy**, backend vẫn cố gọi
> và chat / tóm tắt sẽ **báo lỗi** chứ **không** tự chuyển sang AI dự phòng. Chế độ A bắt buộc để trống biến này
> rồi `docker compose up -d backend` lại.

Lần đầu chế độ B/C: `ollama-pull` tải `qwen2.5:7b` (~4.4 GB). Model nằm trong volume `dev_radar_ai_ollama_data`, lần sau không tải lại.
Kiểm tra model đã có chưa (không cần bật Ollama):

```bash
docker run --rm -v dev_radar_ai_ollama_data:/root/.ollama --entrypoint sh ollama/ollama:0.5.7 \
  -c "ls /root/.ollama/models/manifests/registry.ollama.ai/library"
```

Lỗi `failed to fetch oauth token ... auth.docker.io` khi build = mạng chập chờn tới Docker Hub: **chạy lại đúng lệnh đó**.

### 3.3. Nạp dữ liệu demo

Container backend tự chạy `alembic upgrade head` khi khởi động. Sau đó:

```bash
docker compose exec backend python -m scripts.seed      # chạy nhiều lần không sao
```

Tạo tài khoản **`demo@devradar.dev` / `demo1234`**, ~30 repo mẫu và 30 ngày lịch sử sao giả lập.

### 3.4. Kiểm tra sức khoẻ

```bash
curl -s http://localhost:$PORT/health                    # {"status":"ok"}
docker compose exec -T backend alembic current           # phải là "(head)"
docker compose ps                                        # các service đều Up / healthy
# Video engine (nội bộ):
docker compose exec -T video-engine python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:9000/health').read().decode())"
# AI engine (chế độ B/C):
docker compose exec -T ai-engine python -c "import urllib.request;print(urllib.request.urlopen('http://localhost:8000/health').read().decode())"
docker exec devradar_ollama ollama ps                    # qwen2.5:7b ... 100% GPU (sau lần gọi đầu)
```

Đạt khi: backend `ok`; video-engine `ffmpeg/fonts/voice` đều `ok`; ai-engine `{"status":"ok","db":"ok","ollama":"ok"}`.
Swagger để thử API: `http://localhost:$PORT/docs` (bấm **Authorize**, dán `access_token` từ `POST /api/v1/auth/login`).

### 3.5. Chạy app Flutter

```bash
cd mobile
flutter pub get
```

| Thiết bị | Lệnh |
|---|---|
| **Emulator Android** | `flutter emulators --launch <tên_avd>` → chờ `adb shell getprop sys.boot_completed` ra `1` → `flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:$PORT` |
| Web (Chrome/Edge) | `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:$PORT` |
| Điện thoại thật cùng Wi-Fi | `flutter run --dart-define=API_BASE_URL=http://<IP-LAN-của-máy>:$PORT` |

- `10.0.2.2` là địa chỉ máy tính chủ nhìn từ emulator Android. **Phải truyền đúng `$PORT`** nếu đã đổi `BACKEND_PORT`.
- Lần build đầu mất vài phút. Cảnh báo *"Kotlin Gradle Plugin… will cause build failures in future versions"* là **cảnh báo**, không phải lỗi.
- `flutter run` chạy nền (không có bàn phím) sẽ **thoát khi emulator tắt**. Muốn thấy code mới: dừng rồi chạy lại.
- Xác nhận app chạy: `adb exec-out screencap -p > screen.png` rồi xem ảnh: màn đăng nhập hoặc feed "Dành cho bạn".

**Windows:** `run.bat` gom các bước trên (chọn 1–4). Mục **2 (emulator)** hiện **hỏng**: các đường dẫn `E:\tools\…` ở
dòng 107–113 của `run.bat` bị lỗi ký tự (`\t`, `\a` thành tab/ký tự lạ), nên không tìm thấy Android SDK nếu `adb`
không có trong PATH. Dùng lệnh thủ công ở bảng trên cho tới khi sửa.

---

## 4. Bật và kiểm tra từng tính năng

| Tính năng | Cần | Cách kiểm tra nhanh |
|---|---|---|
| Đăng nhập email | 3.3 | Đăng nhập `demo@devradar.dev` / `demo1234` |
| Đăng nhập Google/GitHub | Khoá OAuth trong `.env` | Nút Google/GitHub trên màn đăng nhập. Trống khoá = nút báo chưa cấu hình |
| Feed, tìm kiếm, chi tiết, biểu đồ sao | 3.3 | Mở tab Khám phá, bấm chip ngôn ngữ, mở một repo |
| Bộ sưu tập, ghi chú, lộ trình, thống kê | 3.3 | Thêm repo vào bộ sưu tập / đổi trạng thái học → tab Thống kê |
| Offline cache | – | Tắt backend (`docker compose stop backend`), kéo làm mới: hiện thanh "dữ liệu từ lúc…" |
| Tóm tắt AI + chat RAG | Chế độ B/C, **và repo đã được index** (4.1) | Mở repo → "Hỏi đáp AI về repo này" → câu trả lời có "Nguồn trích dẫn" |
| Video phân tích / video lộ trình | `video-engine` chạy | Chi tiết repo → icon phim; hoặc video lộ trình. Dựng mất 30–60 s |
| Thông báo release mới | – | Mục 4.2 |
| Nhắc học hằng ngày | Quyền thông báo | Cài đặt → bật nhắc, đặt giờ sát hiện tại (có thể trễ vài phút) |

### 4.1. Làm cho chat AI trả lời được (index README)

Chat chỉ trả lời từ các đoạn README đã **index** vào pgvector. Kiểm tra repo nào đã index:

```bash
docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "select r.id, r.full_name, count(e.id) chunks from repos r join repo_embeddings e on e.repo_id = r.id group by r.id order by chunks desc limit 20;"'
```

(Chạy bằng Git Bash. PowerShell làm rơi dấu `"` khi truyền vào container: khi đó viết thẳng giá trị `DB_USER` / `DB_NAME` trong `.env` vào lệnh.)

Có 3 cách để repo được index:

1. **Cron** `generate_summaries` (30 phút/lần, 10 repo/lần) – chỉ xử lý repo **chưa có tóm tắt**.
   Chạy ngay: `docker compose exec backend python -m scripts.run_job generate_summaries` (`--list` để xem các job).
2. **Nút "Tạo tóm tắt AI"** ở màn chi tiết – cũng chỉ chạy khi repo **chưa có tóm tắt**; tự lấy README từ GitHub nếu thiếu.
3. **Làm lại thủ công** – bắt buộc cho các trường hợp sau, vì cách 1 và 2 **bỏ qua** repo đã có tóm tắt:
   - Repo được tóm tắt bằng AI dự phòng (lúc ai-engine chưa bật) → có tóm tắt nhưng **không có index** → chat luôn trả lời "Không tìm thấy trong tài liệu".
   - Repo seed: README trong seed chỉ ~500 ký tự, không đủ để hỏi đáp.

   Script dưới đây lấy README thật từ GitHub, xoá tóm tắt cũ, tóm tắt + index lại bằng AI thật (sửa danh sách `NAMES`):

   ```bash
   docker compose exec -T -w /app backend python - <<'EOF'
   from sqlalchemy import delete, select
   from app.db.session import SessionLocal
   from app.jobs.ai_jobs import summarize_repo
   from app.models import Repo, RepoSummary
   from app.services import github_client

   NAMES = ["ollama/ollama", "langchain-ai/langchain", "fastapi/fastapi"]
   for name in NAMES:
       with SessionLocal() as db:
           repo = db.scalar(select(Repo).where(Repo.full_name == name))
           readme = github_client.get_readme(name) if repo else None
           if not readme:
               print(f"{name}: skipped (not in DB or no README)")
               continue
           repo.readme = readme
           db.execute(delete(RepoSummary).where(RepoSummary.repo_id == repo.id))
           db.commit()
           repo_id, full_name = repo.id, repo.full_name
           summary = summarize_repo(db, repo_id, full_name, readme)
           print(f"{name}: {len(readme)} chars, model={summary.model}")
   EOF
   ```

   Đạt khi mỗi dòng in `model=qwen2.5:7b` (mất ~4–7 s/repo trên RTX 3060). Lưu ý: dữ liệu này chỉ nằm trong DB local, không theo git.

Thử chat qua API (sau khi index):

```bash
TOKEN=$(curl -s -X POST http://localhost:$PORT/api/v1/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"demo@devradar.dev","password":"demo1234"}' | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
curl -s -X POST http://localhost:$PORT/api/v1/chat/<repo_id> -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"question":"How do I install it?"}'
```

Câu trả lời đúng có `sources` không rỗng. Trước khi demo, xoá lịch sử chat cũ (nút thùng rác trên màn chat) nếu còn câu "(Chế độ dự phòng…)".

### 4.2. Demo thông báo release mới

Chưa có push FCM thật: app hỏi backend khi mở app / quay lại từ nền và hiện **local notification**.

1. Trên app: đăng nhập, **Theo dõi** một repo (vd. `flutter/flutter`), cho phép thông báo, đưa app xuống nền.
2. Giả lập release: `docker compose exec backend python -m scripts.simulate_release flutter/flutter`
3. Mở lại app → thông báo hiện; bấm vào mở đúng repo.

**Lần đầu trên máy/tài khoản mới không hiện popup** (app chỉ ghi nhớ mốc để không hiện lại thông báo cũ):
chạy bước 2 một lần, mở app, rồi mới demo thật. Mỗi lần dùng tag khác (bỏ trống để tự sinh `demo-<thời gian>`).

---

## 5. Kiểm thử

| Phần | Lệnh | Ghi chú |
|---|---|---|
| Flutter | `cd mobile && flutter test` | ~166 test, không cần backend |
| Flutter lint | `cd mobile && flutter analyze` | |
| Backend (venv) | `cd backend && py -3.12 -m venv .venv && .venv/Scripts/python -m pip install -r requirements-dev.txt && .venv/Scripts/python -m pytest -q` | SQLite in-memory, không cần Postgres |
| Backend (không venv) | `MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W 2>/dev/null \|\| pwd)/backend:/src" -w /src dev_radar_ai-backend sh -c "pip install -q -r requirements-dev.txt && python -m pytest -q -p no:cacheprovider"` | Image backend **không** chứa `tests/` nên phải mount source; ~293 test. `MSYS_NO_PATHCONV` / `pwd -W` để Git Bash không đổi sai đường dẫn |
| AI engine | Xem mục test trong [ai-engine/README.md](ai-engine/README.md) | |

Báo kết quả thật (số pass/fail). Không nói "đã chạy test" nếu chưa chạy.

---

## 6. Quy tắc khi sửa code

- **Flutter:** UI → Bloc/Cubit → Repository → DataSource. Màn hình không gọi API trực tiếp.
  Dữ liệu đọc qua `fetchWithCache` (`data/repositories/cache_policy.dart`) để có offline cache.
- **Chuyển cảnh có key:** dùng `SafeAnimatedSwitcher` (`presentation/widgets/common/`), **không** dùng `AnimatedSwitcher`
  với key cố định như `'loading'` – trạng thái đổi nhanh sẽ gây lỗi "Duplicate keys found" (màn hình đỏ).
- **Backend:** route mỏng, logic ở `services/`. Đổi model → `alembic revision --autogenerate -m "..."` (khi DB đang chạy),
  đọc lại file sinh ra, rồi `alembic upgrade head`. Định dạng lỗi chung ở `core/errors.py`.
- **AI engine:** bảng `repo_embeddings` thuộc ai-engine (tự tạo khi khởi động), backend không đụng vào.
- **Git:** Conventional Commits (`feat(fe): …`, `fix(be): …`, `style(fe): …`). Nhánh tích hợp là `develop`;
  quy trình fork + Pull Request trong [CONTRIBUTING.md](CONTRIBUTING.md). Chỉ commit / push khi người dùng yêu cầu.
- Không commit `.env`, file build, video, model.

---

## 7. Sự cố thường gặp

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `failed to connect to the docker API` | Docker Desktop chưa chạy | Mở Docker Desktop, chờ `docker info` chạy được |
| `failed to fetch oauth token` khi build | Mạng tới Docker Hub chập chờn | Chạy lại lệnh |
| Port đã bị chiếm | App khác dùng 5432/8080 | Đổi `DB_PORT` / `BACKEND_PORT`, nhớ đổi `API_BASE_URL` của app theo |
| App báo không kết nối được backend | Sai `API_BASE_URL` hoặc sai cổng | Emulator: `http://10.0.2.2:$PORT`; điện thoại thật: IP LAN; kiểm tra `curl localhost:$PORT/health` |
| Chat/tóm tắt báo lỗi "AI đang bận" / 502 | `AI_ENGINE_URL` có giá trị nhưng ai-engine không chạy | Bật chế độ B/C, hoặc để trống `AI_ENGINE_URL` rồi restart backend |
| Chat luôn "Không tìm thấy trong tài liệu" | Repo chưa index / chỉ có tóm tắt dự phòng / README seed quá ngắn | Mục 4.1, cách 3 |
| Chat lần đầu rất chậm hoặc timeout | Model đang nạp lên GPU | Chờ `ollama ps` hiện model; CPU: dùng `qwen2.5:3b` |
| Màn hình đỏ "Duplicate keys found" | `AnimatedSwitcher` với key cố định | Dùng `SafeAnimatedSwitcher` |
| `adb: no devices` / `flutter run` tự thoát | Emulator đã tắt | Bật lại emulator, chạy lại `flutter run` |
| Chữ tiếng Việt bị vỡ khi gọi API bằng PowerShell | PowerShell 5.1 đọc JSON sai bảng mã | Chỉ là hiển thị; dùng Git Bash/curl hoặc xem trên app |
| Không có popup thông báo lần đầu | App ghi mốc lần đầu | Mục 4.2 |

---

## 8. Giới hạn đã biết (đừng hứa với người dùng)

- **Chưa có push FCM:** backend đã có bảng `device_tokens` và API đăng ký token, nhưng `send_push()` còn để trống.
- **Lịch sử sao lúc đầu là dữ liệu giả lập** từ seed (GitHub không cung cấp lịch sử sao).
- Video repo: câu đọc ở slide 2 là câu mẫu chung, repo nào cũng giống nhau.
- Render video chạy đồng bộ (30–60 s), chưa có hàng đợi; chưa có job dọn video cũ.
- `video_player` không hỗ trợ Windows desktop: xem video trên Android/iOS/web.
- Câu trả lời chat hiển thị dạng chữ thường (`SelectableText`), chưa render markdown.
