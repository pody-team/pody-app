"""
NewsSource Model - Represents the news_sources table
"""
from sqlalchemy import Column, BigInteger, String, Float
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()


class NewsSource(Base):
    """
    NewsSource entity representing a news source in the database.
    
    Attributes:
        id: Unique identifier (bigint)
        domain: Domain name of the news source
        name: Display name of the news source
        reliability_score: Score indicating source reliability (0.0 - 1.0)
        rss_url: URL of the RSS feed
        status: Source status (e.g., 'ACTIVE', 'INACTIVE')
    """
    __tablename__ = 'news_sources'
    
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    domain = Column(String, nullable=False)
    name = Column(String, nullable=False)
    reliability_score = Column(Float, default=0.5)
    rss_url = Column(String, nullable=False)
    status = Column(String, nullable=False, default='ACTIVE')
    
    def __repr__(self):
        return f"<NewsSource(id={self.id}, name='{self.name}', status='{self.status}')>"
