"""
Article model.
"""
from datetime import datetime

from sqlalchemy import BigInteger, Column, DateTime, String, Text
from sqlalchemy.orm import relationship

from .base import Base


class Article(Base):
    __tablename__ = "articles"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    author = Column(String, nullable=True)
    content = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    original_url = Column(String, nullable=False, unique=True, index=True)
    published_at = Column(DateTime, nullable=True)
    source_id = Column(BigInteger, nullable=False)
    status = Column(String, nullable=False, default="PUBLISHED")
    summary = Column(Text, nullable=True)
    thumbnail_url = Column(String(1000), nullable=True)
    title = Column(String, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    category_links = relationship("CategoryArticle", back_populates="article", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Article(id={self.id}, title='{self.title[:30]}...', source_id={self.source_id})>"
