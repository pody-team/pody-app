from typing import Optional, List, Tuple, Any
from datetime import datetime
from sqlalchemy import select, or_, update, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.dialects.postgresql import insert

from models.article import Article, ArticleCategory, ArticleStat, ArticleInteraction, ArticleMetric


class ArticleRepository:
    """
    Repository for accessing articles and related extension tables.
    """
    
    def __init__(self, session: AsyncSession):
        """Initialize repository with database session."""
        self.session = session
    
    async def get_by_id(self, article_id: int) -> Optional[Article]:
        """Fetch an article by its ID."""
        stmt = select(Article).where(Article.id == article_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def exists_by_url(self, original_url: str) -> bool:
        """Check if an article with the given URL exists."""
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
        """Insert a new article."""
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
        await self.session.flush()
        
        # Initialize stats for this article
        stats = ArticleStat(article_id=new_article.id, view_count=0)
        self.session.add(stats)
        
        await self.session.refresh(new_article)
        return new_article

    async def add_category(self, article_id: int, category_name: str) -> None:
        """Add a category to an article (in separate table)."""
        cat = ArticleCategory(article_id=article_id, category_name=category_name)
        self.session.add(cat)

    async def list_articles_with_extra(
        self, 
        limit: int = 20, 
        offset: int = 0, 
        category: Optional[str] = None,
        query: Optional[str] = None
    ) -> List[Tuple[Article, Optional[str], int]]:
        """
        List/Search articles with categories and view counts.
        Returns a list of (Article, CategoryName, ViewCount).
        """
        # Subquery for view count to avoid complex joins in simple list
        # But for pagination, we join.
        stmt = select(
            Article, 
            ArticleCategory.category_name, 
            func.coalesce(ArticleStat.view_count, 0)
        ).outerjoin(
            ArticleCategory, Article.id == ArticleCategory.article_id
        ).outerjoin(
            ArticleStat, Article.id == ArticleStat.article_id
        ).order_by(Article.published_at.desc())
        
        if category:
            stmt = stmt.where(ArticleCategory.category_name == category)
        
        if query:
            search_query = f"%{query}%"
            stmt = stmt.where(or_(
                Article.title.ilike(search_query),
                Article.summary.ilike(search_query)
            ))
            
        stmt = stmt.limit(limit).offset(offset)
        result = await self.session.execute(stmt)
        return [(row[0], row[1], row[2]) for row in result.all()]

    async def get_article_detail(self, article_id: int) -> Optional[Tuple[Article, List[str], int]]:
        """Fetch article detail with all categories and stats."""
        stmt = (
            select(
                Article,
                func.array_remove(
                    func.array_agg(func.distinct(ArticleCategory.category_name)),
                    None,
                ).label("categories"),
                func.coalesce(ArticleStat.view_count, 0).label("view_count"),
            )
            .outerjoin(ArticleCategory, Article.id == ArticleCategory.article_id)
            .outerjoin(ArticleStat, Article.id == ArticleStat.article_id)
            .where(Article.id == article_id)
            .group_by(Article.id, ArticleStat.view_count)
        )
        result = await self.session.execute(stmt)
        row = result.first()
        if not row:
            return None

        categories = row.categories or []
        return (row[0], categories, row.view_count)

    async def increment_view_count(self, article_id: int) -> None:
        """Increment view count in the article_stats table."""
        stmt = insert(ArticleStat).values(
            article_id=article_id,
            view_count=1,
            updated_at=datetime.utcnow(),
        )
        stmt = stmt.on_conflict_do_update(
            index_elements=[ArticleStat.article_id],
            set_={
                "view_count": ArticleStat.view_count + 1,
                "updated_at": datetime.utcnow(),
            },
        )
        await self.session.execute(stmt)

    async def add_interaction(self, article_id: int, user_id: int, interaction_type: str) -> None:
        """Record a user interaction."""
        interaction = ArticleInteraction(
            article_id=article_id,
            user_id=user_id,
            interaction_type=interaction_type.upper()
        )
        self.session.add(interaction)

    async def track_metric(self, article_id: int, user_id: int, reading_time_seconds: int) -> None:
        """Record reading metrics."""
        metric = ArticleMetric(
            article_id=article_id,
            user_id=user_id,
            reading_time_seconds=reading_time_seconds
        )
        self.session.add(metric)
