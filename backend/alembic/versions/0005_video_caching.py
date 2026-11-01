"""video caching

Revision ID: 0005
Revises: 0004
Create Date: 2026-11-01 12:00:00

- Add video_type and repo_id to generated_videos
- Add indexes for repo_id and video_type
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0005"
down_revision: Union[str, Sequence[str], None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "generated_videos",
        sa.Column("video_type", sa.String(length=32), nullable=False, server_default="roadmap"),
    )
    op.add_column(
        "generated_videos",
        sa.Column("repo_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_generated_videos_repo_id_repos",
        "generated_videos",
        "repos",
        ["repo_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_generated_videos_video_type", "generated_videos", ["video_type"], unique=False
    )
    op.create_index(
        "ix_generated_videos_repo_id", "generated_videos", ["repo_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_generated_videos_repo_id", table_name="generated_videos")
    op.drop_index("ix_generated_videos_video_type", table_name="generated_videos")
    op.drop_constraint("fk_generated_videos_repo_id_repos", "generated_videos", type_="foreignkey")
    op.drop_column("generated_videos", "repo_id")
    op.drop_column("generated_videos", "video_type")
