"""
Article Model - Represents the articles table
"""
from datetime import datetime
from sqlalchemy import Column, BigInteger, String, Text, DateTime
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class Article(Base):
    """
    Article entity representing a news article in the database.
    
    Attributes:
        id: Unique identifier (bigint)
        author: Article author name
        content: Full article content (text)
        created_at: Timestamp when record was created
        original_url: Original URL of the article (used for duplicate detection)
        published_at: Timestamp when article was published
        source_id: Foreign key reference to news_sources.id (bigint, logical link only)
        status: Article status (e.g., 'ACTIVE', 'DRAFT')
        summary: Article summary/excerpt
        thumbnail_url: Cover image URL extracted from RSS enclosure / media tags
        title: Article title
        updated_at: Timestamp when record was last updated
    """
    __tablename__ = 'articles'
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    author = Column(String, nullable=True)
    content = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    original_url = Column(String, nullable=False, unique=True, index=True)
    published_at = Column(DateTime, nullable=True)
    source_id = Column(BigInteger, nullable=False)  # Logical FK - no strict constraint
    status = Column(String, nullable=False, default='PUBLISHED')
    summary = Column(Text, nullable=True)
    thumbnail_url = Column(String(1000), nullable=True)
    title = Column(String, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def __repr__(self):
        return f"<Article(id={self.id}, title='{self.title[:30]}...', source_id={self.source_id})>"


class ArticleCategory(Base):
    """Articles categorized by tags/topics."""
    __tablename__ = 'article_categories'
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    article_id = Column(BigInteger, nullable=False, index=True)
    category_name = Column(String(100), nullable=False, index=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class ArticleStat(Base):
    """Stats for articles like total views."""
    __tablename__ = 'article_stats'
    
    article_id = Column(BigInteger, primary_key=True)
    view_count = Column(BigInteger, default=0, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)


class ArticleInteraction(Base):
    """User interactions with articles (LIKE/LOVE)."""
    __tablename__ = 'article_interactions'
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    article_id = Column(BigInteger, nullable=False, index=True)
    user_id = Column(BigInteger, nullable=False, index=True)
    interaction_type = Column(String(50), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class ArticleMetric(Base):
    """Engagement metrics like reading time."""
    __tablename__ = 'article_metrics'
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    article_id = Column(BigInteger, nullable=False, index=True)
    user_id = Column(BigInteger, nullable=False, index=True)
    reading_time_seconds = Column(BigInteger, nullable=False, default=0)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
