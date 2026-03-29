"""
CategoryArticle model.
"""
from datetime import datetime

from sqlalchemy import BigInteger, Boolean, Column, DateTime, Float, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from .base import Base


class CategoryArticle(Base):
    __tablename__ = "category_articles"
    __table_args__ = (
        UniqueConstraint(
            "article_id",
            "category_id",
            "assignment_source",
            name="uq_category_articles_article_category_source",
        ),
        Index("ix_category_articles_article_primary", "article_id", "assignment_source", "is_primary"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    article_id = Column(BigInteger, ForeignKey("articles.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(UUID(as_uuid=False), ForeignKey("categories.id", ondelete="CASCADE"), nullable=False, index=True)
    assignment_source = Column(String(20), nullable=False, default="manual")
    is_primary = Column(Boolean, nullable=False, default=False)
    match_rank = Column(Integer, nullable=True)
    score = Column(Float, nullable=True)
    model_name = Column(String(120), nullable=True)
    embedding_version = Column(String(40), nullable=True)
    assigned_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    article = relationship("Article", back_populates="category_links")
    category = relationship("Category", back_populates="article_links")
