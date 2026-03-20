"""
Article category model.
"""
from datetime import datetime

from sqlalchemy import BigInteger, Column, DateTime, String

from .base import Base


class ArticleCategory(Base):
    __tablename__ = "article_categories"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    article_id = Column(BigInteger, nullable=False, index=True)
    category_name = Column(String(100), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
