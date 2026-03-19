"""
Article Repository - Data Access Layer for articles table
"""
from typing import Optional
from datetime import datetime
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.article import Article


class ArticleRepository:
    """
    Repository for accessing articles table.
    Handles all database operations related to articles.
    """
    
    def __init__(self, session: AsyncSession):
        """
        Initialize repository with database session.
        
        Args:
            session: SQLAlchemy async session
        """
        self.session = session
    
    async def exists_by_url(self, original_url: str) -> bool:
        """
        Check if an article with the given URL already exists in the database.
        
        Args:
            original_url: The original URL of the article
            
        Returns:
            bool: True if article exists, False otherwise
        """
        stmt = select(Article.id).where(Article.original_url == original_url)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none() is not None
    
    async def insert_article(
        self,
        title: str,
        original_url: str,
        source_id: int,
        content: Optional[str] = None,
        author: Optional[str] = None,
        summary: Optional[str] = None,
        thumbnail_url: Optional[str] = None,
        published_at: Optional[datetime] = None,
        status: str = 'PUBLISHED'
    ) -> Article:
        """
        Insert a new article into the database.
        
        Args:
            title: Article title
            original_url: Original URL of the article
            source_id: ID of the news source
            content: Full article content
            author: Article author
            summary: Article summary
            published_at: Publication timestamp
            status: Article status (default: 'ACTIVE')
            
        Returns:
            Article: The newly created article with ID
        """
        new_article = Article(
            title=title,
            original_url=original_url,
            source_id=source_id,
            content=content,
            author=author,
            summary=summary,
            thumbnail_url=thumbnail_url,
            published_at=published_at or datetime.utcnow(),
            status=status,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )
        
        self.session.add(new_article)
        await self.session.flush()  # Flush to get the ID
        await self.session.refresh(new_article)  # Refresh to get all computed fields
        
        return new_article
    
    async def get_by_url(self, original_url: str) -> Optional[Article]:
        """
        Fetch an article by its original URL.
        
        Args:
            original_url: The original URL of the article
            
        Returns:
            Optional[Article]: The article if found, None otherwise
        """
        stmt = select(Article).where(Article.original_url == original_url)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def list_articles(self, limit: int = 20, offset: int = 0) -> list[Article]:
        """
        List articles with pagination.
        
        Args:
            limit: Maximum number of articles to return
            offset: Number of articles to skip
            
        Returns:
            list[Article]: List of articles ordered by published_at descending
        """
        stmt = select(Article).order_by(Article.published_at.desc()).limit(limit).offset(offset)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())
