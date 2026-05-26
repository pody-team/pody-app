from __future__ import annotations

from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from models import Article, Category, CategoryArticle


class ArticleCategoryProjectionRepository:
    """Repository de consumer Kafka ghi ket qua category semantic vao article_service."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def has_processed_event(self, *, event_id: UUID) -> bool:
        """Kiem tra bang inbox de lan giao Kafka bi lap van idempotent."""
        existing = await self.session.execute(
            text(
                """
                SELECT 1
                FROM inbox_processed_events
                WHERE event_id = CAST(:event_id AS uuid)
                LIMIT 1
                """
            ),
            {"event_id": str(event_id)},
        )
        return existing.scalar_one_or_none() is not None

    async def mark_event_processed(
        self,
        *,
        event_id: UUID,
        source_service: str,
        event_type: str,
    ) -> None:
        """Ghi nhan event da consume sau khi apply hoac chu dong skip."""
        await self.session.execute(
            text(
                """
                INSERT INTO inbox_processed_events (event_id, source_service, event_type)
                VALUES (CAST(:event_id AS uuid), :source_service, :event_type)
                ON CONFLICT (event_id) DO NOTHING
                """
            ),
            {
                "event_id": str(event_id),
                "source_service": source_service,
                "event_type": event_type,
            },
        )

    async def article_exists(self, *, article_id: int) -> bool:
        """Xac nhan bai bao nguon con ton tai truoc khi ghi lien ket category."""
        result = await self.session.execute(
            select(Article.id).where(Article.id == article_id).limit(1)
        )
        return result.scalar_one_or_none() is not None

    async def list_active_category_ids(self, *, category_ids: list[str]) -> set[str]:
        """Loc match tu embedding_service chi giu category dang hoat dong."""
        if not category_ids:
            return set()
        result = await self.session.execute(
            select(Category.id).where(
                Category.id.in_(category_ids),
                Category.is_active.is_(True),
            )
        )
        return {str(category_id) for category_id in result.scalars().all()}

    async def replace_semantic_category_links(
        self,
        *,
        article_id: int,
        matches: list[dict[str, object]],
        model_name: str,
        embedding_version: str,
        assigned_at: datetime,
    ) -> None:
        """Thay the gan category semantic cua bai bao bang ket qua match moi nhat."""
        normalized_assigned_at = _normalize_datetime(assigned_at)
        # Gan semantic duoc tai tao nhu mot projection day du cho moi event bai bao.
        await self.session.execute(
            delete(CategoryArticle).where(
                CategoryArticle.article_id == article_id,
                CategoryArticle.assignment_source == "semantic",
            )
        )

        for match in matches:
            self.session.add(
                CategoryArticle(
                    article_id=article_id,
                    category_id=str(match["category_id"]),
                    assignment_source="semantic",
                    is_primary=bool(match["is_primary"]),
                    match_rank=int(match["match_rank"]),
                    score=float(match["score"]),
                    model_name=model_name,
                    embedding_version=embedding_version,
                    assigned_at=normalized_assigned_at,
                    created_at=normalized_assigned_at,
                    updated_at=normalized_assigned_at,
                )
            )


def _normalize_datetime(value: datetime) -> datetime:
    """Luu timestamp co timezone thanh UTC-naive de khop cot PostgreSQL."""
    if value.tzinfo is None:
        return value
    return value.astimezone(timezone.utc).replace(tzinfo=None)
