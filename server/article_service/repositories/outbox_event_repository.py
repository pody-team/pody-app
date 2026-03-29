"""
Repository for transactional outbox events.
"""
from __future__ import annotations

from datetime import datetime, timedelta
from typing import List

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import OutboxEvent


class OutboxEventRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def claim_pending(self, *, limit: int) -> List[OutboxEvent]:
        stmt = (
            select(OutboxEvent)
            .where(
                OutboxEvent.status == "pending",
                OutboxEvent.available_at <= datetime.utcnow(),
            )
            .order_by(OutboxEvent.created_at.asc())
            .limit(limit)
            .with_for_update(skip_locked=True)
        )
        result = await self.session.execute(stmt)
        events = list(result.scalars())
        for event in events:
            event.status = "publishing"
            event.attempts += 1
            event.last_error = None
        await self.session.flush()
        return events

    async def mark_published(self, *, event_id: str) -> None:
        event = await self.session.get(OutboxEvent, event_id)
        if event is None:
            return
        event.status = "published"
        event.published_at = datetime.utcnow()
        event.last_error = None

    async def mark_failed(
        self,
        *,
        event_id: str,
        error_message: str,
        retry_delay_seconds: float,
        max_attempts: int,
    ) -> None:
        event = await self.session.get(OutboxEvent, event_id)
        if event is None:
            return
        event.last_error = error_message
        if event.attempts >= max_attempts:
            event.status = "failed"
            return
        event.status = "pending"
        event.available_at = datetime.utcnow() + timedelta(seconds=retry_delay_seconds)
