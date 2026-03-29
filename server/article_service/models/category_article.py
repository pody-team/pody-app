"""
CategoryArticle model.
"""
from datetime import datetime

from sqlalchemy import BigInteger, Boolean, Column, DateTime, ForeignKey, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from .base import Base


class CategoryArticle(Base):
    __tablename__ = "category_articles"
    __table_args__ = (
        UniqueConstraint("article_id", "category_id", name="uq_category_articles_article_category"),
        Index("ix_category_articles_article_primary", "article_id", "is_primary"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    article_id = Column(BigInteger, ForeignKey("articles.id", ondelete="CASCADE"), nullable=False, index=True)
    category_id = Column(UUID(as_uuid=False), ForeignKey("categories.id", ondelete="CASCADE"), nullable=False, index=True)
    is_primary = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    article = relationship("Article", back_populates="category_links")
    category = relationship("Category", back_populates="article_links")
