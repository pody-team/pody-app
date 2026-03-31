"""
Article comment model.
"""
from datetime import datetime

from sqlalchemy import BigInteger, Column, DateTime, String, Text

from .base import Base


class ArticleComment(Base):
    __tablename__ = "article_comments"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    article_id = Column(BigInteger, nullable=False, index=True)
    user_id = Column(String(255), nullable=False, index=True)
    user_name = Column(String(255), nullable=True)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
