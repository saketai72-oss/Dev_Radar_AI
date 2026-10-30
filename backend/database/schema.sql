-- Script tạo CSDL DevRadar AI (PostgreSQL 16 + pgvector).
-- Phần backend sinh tự động từ các migration Alembic 0001 -> 0004:
--     cd backend && alembic upgrade head --sql
-- Phần cuối là bảng repo_embeddings của AI Engine (ai-engine/app/core/database.py).
-- Chạy: psql -U <user> -d <database> -f schema.sql

BEGIN;

CREATE TABLE alembic_version (
    version_num VARCHAR(32) NOT NULL, 
    CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num)
);

-- Running upgrade  -> 0001

CREATE TABLE repos (
    id SERIAL NOT NULL, 
    github_id BIGINT NOT NULL, 
    full_name VARCHAR(255) NOT NULL, 
    owner VARCHAR(100) NOT NULL, 
    name VARCHAR(150) NOT NULL, 
    description TEXT, 
    html_url VARCHAR(500) NOT NULL, 
    homepage VARCHAR(500), 
    language VARCHAR(100), 
    topics JSON NOT NULL, 
    stars INTEGER NOT NULL, 
    forks INTEGER NOT NULL, 
    open_issues INTEGER NOT NULL, 
    license VARCHAR(100), 
    owner_avatar_url VARCHAR(500), 
    github_created_at TIMESTAMP WITH TIME ZONE, 
    github_pushed_at TIMESTAMP WITH TIME ZONE, 
    fetched_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    readme TEXT, 
    CONSTRAINT pk_repos PRIMARY KEY (id), 
    CONSTRAINT uq_repos_full_name UNIQUE (full_name), 
    CONSTRAINT uq_repos_github_id UNIQUE (github_id)
);

CREATE INDEX ix_repos_language ON repos (language);

CREATE INDEX ix_repos_stars ON repos (stars);

CREATE TABLE users (
    id SERIAL NOT NULL, 
    email VARCHAR(255) NOT NULL, 
    password_hash VARCHAR(255) NOT NULL, 
    display_name VARCHAR(100) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_users PRIMARY KEY (id)
);

CREATE UNIQUE INDEX ix_users_email ON users (email);

CREATE TABLE chat_messages (
    id SERIAL NOT NULL, 
    user_id INTEGER NOT NULL, 
    repo_id INTEGER NOT NULL, 
    role VARCHAR(20) NOT NULL, 
    content TEXT NOT NULL, 
    sources JSON, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_chat_messages PRIMARY KEY (id), 
    CONSTRAINT fk_chat_messages_repo_id_repos FOREIGN KEY(repo_id) REFERENCES repos (id) ON DELETE CASCADE, 
    CONSTRAINT fk_chat_messages_user_id_users FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_chat_messages_repo_id ON chat_messages (repo_id);

CREATE INDEX ix_chat_messages_user_id ON chat_messages (user_id);

CREATE TABLE collections (
    id SERIAL NOT NULL, 
    user_id INTEGER NOT NULL, 
    name VARCHAR(100) NOT NULL, 
    description TEXT, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_collections PRIMARY KEY (id), 
    CONSTRAINT fk_collections_user_id_users FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_collections_user_id ON collections (user_id);

CREATE TABLE device_tokens (
    id SERIAL NOT NULL, 
    user_id INTEGER NOT NULL, 
    token VARCHAR(500) NOT NULL, 
    platform VARCHAR(20) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_device_tokens PRIMARY KEY (id), 
    CONSTRAINT fk_device_tokens_user_id_users FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
    CONSTRAINT uq_device_tokens_token UNIQUE (token)
);

CREATE INDEX ix_device_tokens_user_id ON device_tokens (user_id);

CREATE TABLE notes (
    id SERIAL NOT NULL, 
    user_id INTEGER NOT NULL, 
    repo_id INTEGER NOT NULL, 
    content TEXT NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_notes PRIMARY KEY (id), 
    CONSTRAINT fk_notes_repo_id_repos FOREIGN KEY(repo_id) REFERENCES repos (id) ON DELETE CASCADE, 
    CONSTRAINT fk_notes_user_id_users FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_notes_repo_id ON notes (repo_id);

CREATE INDEX ix_notes_user_id ON notes (user_id);

CREATE TABLE notifications (
    id SERIAL NOT NULL, 
    user_id INTEGER NOT NULL, 
    type VARCHAR(30) NOT NULL, 
    title VARCHAR(255) NOT NULL, 
    body TEXT, 
    repo_id INTEGER, 
    data JSON, 
    is_read BOOLEAN NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_notifications PRIMARY KEY (id), 
    CONSTRAINT fk_notifications_repo_id_repos FOREIGN KEY(repo_id) REFERENCES repos (id) ON DELETE SET NULL, 
    CONSTRAINT fk_notifications_user_id_users FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX ix_notifications_created_at ON notifications (created_at);

CREATE INDEX ix_notifications_repo_id ON notifications (repo_id);

CREATE INDEX ix_notifications_user_id ON notifications (user_id);

CREATE TABLE repo_releases (
    id SERIAL NOT NULL, 
    repo_id INTEGER NOT NULL, 
    tag_name VARCHAR(255) NOT NULL, 
    name VARCHAR(255), 
    html_url VARCHAR(500), 
    published_at TIMESTAMP WITH TIME ZONE, 
    checked_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_repo_releases PRIMARY KEY (id), 
    CONSTRAINT fk_repo_releases_repo_id_repos FOREIGN KEY(repo_id) REFERENCES repos (id) ON DELETE CASCADE, 
    CONSTRAINT uq_repo_releases_repo_id UNIQUE (repo_id)
);

CREATE TABLE repo_star_snapshots (
    id SERIAL NOT NULL, 
    repo_id INTEGER NOT NULL, 
    date DATE NOT NULL, 
    stars INTEGER NOT NULL, 
    CONSTRAINT pk_repo_star_snapshots PRIMARY KEY (id), 
    CONSTRAINT fk_repo_star_snapshots_repo_id_repos FOREIGN KEY(repo_id) REFERENCES repos (id) ON DELETE CASCADE, 
    CONSTRAINT uq_repo_star_snapshots_repo_id_date UNIQUE (repo_id, date)
);

CREATE INDEX ix_repo_star_snapshots_repo_id ON repo_star_snapshots (repo_id);

CREATE TABLE repo_summaries (
    id SERIAL NOT NULL, 
    repo_id INTEGER NOT NULL, 
    summary TEXT NOT NULL, 
    quickstart TEXT, 
    model VARCHAR(100), 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_repo_summaries PRIMARY KEY (id), 
    CONSTRAINT fk_repo_summaries_repo_id_repos FOREIGN KEY(repo_id) REFERENCES repos (id) ON DELETE CASCADE, 
    CONSTRAINT uq_repo_summaries_repo_id UNIQUE (repo_id)
);

CREATE TABLE user_preferences (
    id SERIAL NOT NULL, 
    user_id INTEGER NOT NULL, 
    kind VARCHAR(20) NOT NULL, 
    value VARCHAR(100) NOT NULL, 
    CONSTRAINT pk_user_preferences PRIMARY KEY (id), 
    CONSTRAINT fk_user_preferences_user_id_users FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
    CONSTRAINT uq_user_preferences_user_id_kind_value UNIQUE (user_id, kind, value)
);

CREATE INDEX ix_user_preferences_user_id ON user_preferences (user_id);

CREATE TABLE user_repos (
    id SERIAL NOT NULL, 
    user_id INTEGER NOT NULL, 
    repo_id INTEGER NOT NULL, 
    status VARCHAR(20) NOT NULL, 
    started_at TIMESTAMP WITH TIME ZONE, 
    completed_at TIMESTAMP WITH TIME ZONE, 
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_user_repos PRIMARY KEY (id), 
    CONSTRAINT fk_user_repos_repo_id_repos FOREIGN KEY(repo_id) REFERENCES repos (id) ON DELETE CASCADE, 
    CONSTRAINT fk_user_repos_user_id_users FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
    CONSTRAINT uq_user_repos_user_id_repo_id UNIQUE (user_id, repo_id)
);

CREATE INDEX ix_user_repos_repo_id ON user_repos (repo_id);

CREATE INDEX ix_user_repos_user_id ON user_repos (user_id);

CREATE TABLE watchlist (
    id SERIAL NOT NULL, 
    user_id INTEGER NOT NULL, 
    repo_id INTEGER NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_watchlist PRIMARY KEY (id), 
    CONSTRAINT fk_watchlist_repo_id_repos FOREIGN KEY(repo_id) REFERENCES repos (id) ON DELETE CASCADE, 
    CONSTRAINT fk_watchlist_user_id_users FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
    CONSTRAINT uq_watchlist_user_id_repo_id UNIQUE (user_id, repo_id)
);

CREATE INDEX ix_watchlist_repo_id ON watchlist (repo_id);

CREATE INDEX ix_watchlist_user_id ON watchlist (user_id);

CREATE TABLE collection_items (
    id SERIAL NOT NULL, 
    collection_id INTEGER NOT NULL, 
    repo_id INTEGER NOT NULL, 
    added_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_collection_items PRIMARY KEY (id), 
    CONSTRAINT fk_collection_items_collection_id_collections FOREIGN KEY(collection_id) REFERENCES collections (id) ON DELETE CASCADE, 
    CONSTRAINT fk_collection_items_repo_id_repos FOREIGN KEY(repo_id) REFERENCES repos (id) ON DELETE CASCADE, 
    CONSTRAINT uq_collection_items_collection_id_repo_id UNIQUE (collection_id, repo_id)
);

CREATE INDEX ix_collection_items_collection_id ON collection_items (collection_id);

CREATE INDEX ix_collection_items_repo_id ON collection_items (repo_id);

INSERT INTO alembic_version (version_num) VALUES ('0001') RETURNING alembic_version.version_num;

-- Running upgrade 0001 -> 0002

ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;

CREATE TABLE oauth_accounts (
    id SERIAL NOT NULL, 
    user_id INTEGER NOT NULL, 
    provider VARCHAR(20) NOT NULL, 
    provider_user_id VARCHAR(255) NOT NULL, 
    email VARCHAR(255), 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_oauth_accounts PRIMARY KEY (id), 
    CONSTRAINT fk_oauth_accounts_user_id_users FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
    CONSTRAINT uq_oauth_accounts_provider_provider_user_id UNIQUE (provider, provider_user_id)
);

CREATE INDEX ix_oauth_accounts_user_id ON oauth_accounts (user_id);

UPDATE alembic_version SET version_num='0002' WHERE alembic_version.version_num = '0001';

-- Running upgrade 0002 -> 0003

ALTER TABLE users ADD COLUMN avatar_url VARCHAR(500);

UPDATE alembic_version SET version_num='0003' WHERE alembic_version.version_num = '0002';

-- Running upgrade 0003 -> 0004

CREATE TABLE generated_videos (
    id SERIAL NOT NULL, 
    job_id VARCHAR(64) NOT NULL, 
    user_id INTEGER NOT NULL, 
    duration_seconds FLOAT NOT NULL, 
    size_bytes INTEGER NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL, 
    CONSTRAINT pk_generated_videos PRIMARY KEY (id), 
    CONSTRAINT fk_generated_videos_user_id_users FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
    CONSTRAINT uq_generated_videos_job_id UNIQUE (job_id)
);

CREATE INDEX ix_generated_videos_job_id ON generated_videos (job_id);

CREATE INDEX ix_generated_videos_user_id ON generated_videos (user_id);

UPDATE alembic_version SET version_num='0004' WHERE alembic_version.version_num = '0003';

COMMIT;


-- AI Engine: đoạn README + vector embedding 384 chiều cho hỏi đáp RAG

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS repo_embeddings (
    id        SERIAL PRIMARY KEY,
    repo_id   INTEGER NOT NULL,
    path      TEXT NOT NULL,
    content   TEXT NOT NULL,
    embedding vector(384) NOT NULL
);

CREATE INDEX IF NOT EXISTS repo_embeddings_repo_id_idx ON repo_embeddings (repo_id);
