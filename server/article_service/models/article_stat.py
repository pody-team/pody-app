"""
Article stat model.
"""
from datetime import datetime

from sqlalchemy import BigInteger, Column, DateTime

from .base import Base


class ArticleStat(Base):
    __tablename__ = "article_stats"

    article_id = Column(BigInteger, primary_key=True)
    view_count = Column(BigInteger, default=0, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
