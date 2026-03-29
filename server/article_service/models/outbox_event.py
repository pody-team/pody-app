"""
Transactional outbox model for asynchronous integrations.
"""
from datetime import datetime

from sqlalchemy import Column, DateTime, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID

from .base import Base


class OutboxEvent(Base):
    __tablename__ = "outbox_events"

    id = Column(UUID(as_uuid=False), primary_key=True)
    aggregate_type = Column(String(80), nullable=False, index=True)
    aggregate_id = Column(UUID(as_uuid=False), nullable=False, index=True)
    event_type = Column(String(120), nullable=False, index=True)
    payload_version = Column(Integer, nullable=False, default=1)
    payload = Column(JSONB, nullable=False)
    attempts = Column(Integer, nullable=False, default=0)
    last_error = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default="pending", index=True)
    available_at = Column(DateTime, nullable=False, default=datetime.utcnow, index=True)
    published_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
