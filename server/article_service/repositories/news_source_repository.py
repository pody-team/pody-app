"""
NewsSource Repository - Data Access Layer for news_sources table
"""
from typing import List, Optional
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.news_source import NewsSource


class NewsSourceRepository:
    """
    Repository for accessing news_sources table.
    Handles all database operations related to news sources.
    """
    
    def __init__(self, session: AsyncSession):
        """
        Initialize repository with database session.
        
        Args:
            session: SQLAlchemy async session
        """
        self.session = session
    
    async def get_active_sources(self) -> List[NewsSource]:
        """
        Fetch all active news sources from the database.
        
        Returns:
            List[NewsSource]: List of active news sources
        """
        stmt = select(NewsSource).where(NewsSource.status == 'ACTIVE')
        result = await self.session.execute(stmt)
        sources = result.scalars().all()
        return list(sources)
    
    async def get_by_id(self, source_id: int) -> Optional[NewsSource]:
        """
        Fetch a news source by its ID.
        
        Args:
            source_id: The ID of the news source
            
        Returns:
            Optional[NewsSource]: The news source if found, None otherwise
        """
        stmt = select(NewsSource).where(NewsSource.id == source_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()
    
    async def get_all(self) -> List[NewsSource]:
        """
        Fetch all news sources regardless of status.
        
        Returns:
            List[NewsSource]: List of all news sources
        """
        stmt = select(NewsSource)
        result = await self.session.execute(stmt)
        sources = result.scalars().all()
        return list(sources)
