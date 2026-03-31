"""
CategoryUser model.
"""
from datetime import datetime

from sqlalchemy import BigInteger, Column, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from .base import Base


class CategoryUser(Base):
    __tablename__ = "category_users"
    __table_args__ = (
        UniqueConstraint("user_id", "category_id", name="uq_category_users_user_category"),
    )

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String(255), nullable=False, index=True)
    category_id = Column(UUID(as_uuid=False), ForeignKey("categories.id", ondelete="CASCADE"), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    category = relationship("Category", back_populates="user_links")
