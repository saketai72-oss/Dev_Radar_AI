# Kế hoạch Tối ưu Hiệu năng & Cache Video cho DevRadar AI (Orchestration Plan)

> **Mục tiêu**: Xóa bỏ hoàn toàn tình trạng phải render lại video 30–60s mỗi khi xem lại, lưu trữ cache video thông minh, và tối ưu tốc độ phản hồi của AI Engine / Video Engine trên Docker.

---

## 1. Phân tích Hiện trạng & Vấn đề Cần giải quyết

| Vấn đề | Vị trí | Nguyên nhân | Tác hại |
|---|---|---|---|
| **Video không được cache** | `backend/app/api/routes/videos.py` | Luôn tạo `uuid4().hex` mới, không kiểm tra file đã render trước đó. Bảng `generated_videos` không lưu `repo_id` / `video_type`. | Người dùng mất 30–60s mỗi lần mở lại màn hình video. |
| **Mobile luôn bắt render lại** | `mobile/lib/presentation/state/video/` | `RepoVideoScreen` và `RoadmapVideoScreen` gọi `..generate()` mỗi khi khởi tạo; Cubit bị dispose khi bấm Back. | Trải nghiệm bị gián đoạn, tốn tài nguyên server. |
| **FFmpeg CPU-heavy** | `video-engine/app/services/timeline.py` | Bộ lọc `zoompan` chạy 30 FPS trên CPU Docker, preset `veryfast`. | Thời gian encode video kéo dài không cần thiết trên môi trường không có GPU. |
| **AI Engine chậm trên CPU** | `ai-engine/app/core/config.py` | Model mặc định `qwen2.5:7b` quá nặng cho CPU (1.5-3 tokens/s). | Tóm tắt và chat mất 40–90 giây. |

---

## 2. Thiết kế Kiến trúc & Hợp đồng Kỹ thuật (API Contract)

### A. Backend & Database Schema
1. **Schema Update (`backend/app/models/personal.py`)**:
   - Mở rộng model `GeneratedVideo`:
     * `video_type`: String(32), default `"roadmap"`, index=True (`"roadmap"` hoặc `"repo"`).
     * `repo_id`: Integer, nullable, ForeignKey("repos.id", ondelete="CASCADE"), index=True.
2. **Alembic Migration (`backend/alembic/versions/0005_video_caching.py`)**:
   - Thêm cột `video_type` và `repo_id` vào `generated_videos`.
3. **API Routes (`backend/app/api/routes/videos.py`)**:
   - `GET /api/v1/videos/roadmap`: Trả về `RoadmapVideoOut` của video lộ trình gần nhất nếu file MP4 còn tồn tại; 404 nếu chưa có.
   - `POST /api/v1/videos/roadmap?force=false`: Nếu `force=false` và đã có video hợp lệ trên đĩa, trả về ngay lập tức (0.01s). Chỉ render mới khi `force=true` hoặc chưa có video.
   - `GET /api/v1/videos/repos/{repo_id}`: Trả về `RoadmapVideoOut` của video repo gần nhất nếu còn file MP4; 404 nếu chưa có.
   - `POST /api/v1/videos/repos/{repo_id}?force=false`: Kiểm tra cache trước, trả về tức thì nếu có sẵn.

### B. Video Engine & Timeline Optimization
1. **Config (`video-engine/app/core/config.py`)**:
   - Thiết lập `fps = 24` (giảm 20% số frame CPU phải xử lý, mắt thường không phân biệt được với dạng slide thuyết trình).
   - Thiết lập `ffmpeg_preset = "ultrafast"` và truyền cờ `"-threads", "0"` trong `timeline.py`.

### C. Mobile Flutter App
1. **Data Source & Repository (`mobile/lib/data/`)**:
   - Bổ sung `getRoadmapVideo()` và `getRepoVideo(repoId)`.
   - Cập nhật `createRoadmapVideo({bool force = false})` và `createRepoVideo(repoId, {bool force = false})`.
2. **State & UI (`mobile/lib/presentation/`)**:
   - Trong `RepoVideoCubit` & `RoadmapVideoCubit`: Bổ sung hàm `init()` hoặc `checkExisting()` kiểm tra video có sẵn trước. Nếu có sẵn ➔ chuyển ngay sang `LoadStatus.success` hiển thị video player trong 0.1s.
   - Màn hình hiển thị thêm nút icon **"Làm mới video"** (gọi `generate(force: true)`) để người dùng chủ động render lại khi nội dung thay đổi.

### D. AI Engine Configuration
- Cung cấp tùy chọn cấu hình `OLLAMA_MODEL` mặc định sang `qwen2.5:1.5b` trong Docker / env để đạt tốc độ sinh text 15–20 tokens/s trên CPU (hoàn thành tóm tắt trong 3–5 giây).

---

## 3. Phân công Sub-Agents Chạy Song Song (Parallel Execution)

```
                       ┌──> Subagent 1: Backend & DB Architect
                       │    (Alembic, models, videos.py endpoints, backend tests)
                       │
[Orchestrator Plan] ───┼──> Subagent 2: Video & AI Engine Specialist
                       │    (timeline.py 24fps/ultrafast, ai config, engine tests)
                       │
                       └──> Subagent 3: Mobile Flutter Specialist
                            (remote datasource, repository, cubit cache-check, screen refresh button, tests)
```

| Sub-Agent | Phạm vi công việc | File sở hữu | Tiêu chí hoàn thành |
|---|---|---|---|
| **Subagent 1** (`backend-specialist`) | Cập nhật model DB, Alembic migration 0005, triển khai GET/POST cache logic trong `videos.py` | `backend/app/models/personal.py`, `backend/app/api/routes/videos.py`, `backend/alembic/versions/0005_video_caching.py`, `backend/tests/test_videos.py` | `cd backend && pytest` PASS 100% |
| **Subagent 2** (`desktop-developer` / `devops-engineer`) | Tối ưu hóa `timeline.py` (24fps, ultrafast, threads), config AI Engine | `video-engine/app/services/timeline.py`, `video-engine/app/core/config.py`, `ai-engine/app/core/config.py` | `cd video-engine && pytest` & `cd ai-engine && pytest` PASS 100% |
| **Subagent 3** (`mobile-developer`) | Cập nhật data layer & cubits video, kiểm tra video cũ trước khi render, thêm nút refresh video | `mobile/lib/data/datasources/remote/video_remote_datasource.dart`, `mobile/lib/data/repositories/video_repository.dart`, `mobile/lib/presentation/state/video/*`, `mobile/lib/presentation/screens/detail/repo_video_screen.dart`, `mobile/lib/presentation/screens/roadmap/roadmap_video_screen.dart` | `cd mobile && flutter analyze && flutter test` PASS 100% |
