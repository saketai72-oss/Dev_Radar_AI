# DevRadar AI — Kế hoạch Kiểm thử Toàn diện & Phân phối Điều phối (Orchestration Test Plan)

## 1. Tổng quan Kiến trúc & Phạm vi Kiểm thử

Hệ thống **DevRadar AI** bao gồm 4 khối kiến trúc chính:
1. **Backend REST API** (`backend/`): FastAPI, SQLAlchemy, Alembic, PostgreSQL + pgvector, OAuth/JWT, APScheduler jobs.
2. **AI Engine** (`ai-engine/`): Tóm tắt README, RAG, pgvector semantic search, Ollama LLM integration.
3. **Video Engine** (`video-engine/`): Sinh video tóm tắt công nghệ tự động, Piper TTS, FFmpeg render, layout & timeline calculation.
4. **Mobile App** (`mobile/`): Flutter 3.47 (Dart 3.13), BLoC/Cubit architecture, SQLite local caching, Dio networking, responsive widgets.

---

## 2. Ma trận Phân công Sub-Agents Chạy Song Song

| Sub-Agent | Role | Phạm vi Kiểm thử | Công cụ / Runner | Số lượng Test dự kiến |
| --- | --- | --- | --- | --- |
| **Sub-Agent 1** | `Backend Test Specialist` | Xác thực (Auth/OAuth), Repos, Collections, Notes, Learning, Stats, Watchlist, Video API, Cron Jobs | `cd backend && python -m pytest` | ~280 tests |
| **Sub-Agent 2** | `AI & Video Engine Test Specialist` | Tóm tắt README, RAG, pgvector search, Piper TTS, Audio layout, Timeline, Video render | `cd ai-engine && python -m pytest tests` & `cd video-engine && python -m pytest tests` | ~63 tests |
| **Sub-Agent 3** | `Mobile Test Specialist` | Phân tích tĩnh code Dart (`flutter analyze`), BLoC/Cubit state, Repository mock, SQLite cache fallback, Widget tests (Feed, Search, Detail, Chat, Onboarding, Video, Stats) | `cd mobile && flutter analyze && flutter test` | ~150 tests |

---

## 3. Tiêu chí Đánh giá & Bằng chứng Hoàn thành (Exit Gate)
- Tất cả các test suites phải PASS 100%.
- Không có lỗi unhandled exception hoặc crash trong các luồng chính.
- Tổng hợp báo cáo điều phối (Orchestration Report) đầy đủ log thực thi từ từng sub-agent.
