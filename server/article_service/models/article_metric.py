"""
Article metric model.
"""
from datetime import datetime

from sqlalchemy import BigInteger, Column, DateTime, String

from .base import Base


class ArticleMetric(Base):
    __tablename__ = "article_metrics"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    article_id = Column(BigInteger, nullable=False, index=True)
    user_id = Column(String(255), nullable=False, index=True)
    reading_time_seconds = Column(BigInteger, nullable=False, default=0)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
