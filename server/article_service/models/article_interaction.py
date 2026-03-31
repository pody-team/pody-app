"""
Article interaction model.
"""
from datetime import datetime

from sqlalchemy import BigInteger, Column, DateTime, String, UniqueConstraint

from .base import Base


class ArticleInteraction(Base):
    __tablename__ = "article_interactions"
    __table_args__ = (
        UniqueConstraint("article_id", "user_id", name="uq_article_interactions_article_user"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    article_id = Column(BigInteger, nullable=False, index=True)
    user_id = Column(String(255), nullable=False, index=True)
    interaction_type = Column(String(50), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
