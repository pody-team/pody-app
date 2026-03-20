from datetime import datetime
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models import Article, ArticleCategory, ArticleStat


class ArticleWriteRepository:
    """Write-side repository for article ingestion and existence checks."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_id(self, article_id: int) -> Optional[Article]:
        stmt = select(Article).where(Article.id == article_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def exists_by_url(self, original_url: str) -> bool:
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
        status: str = "PUBLISHED",
    ) -> Article:
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
            updated_at=datetime.utcnow(),
        )

        self.session.add(new_article)
        await self.session.flush()

        self.session.add(ArticleStat(article_id=new_article.id, view_count=0))
        await self.session.refresh(new_article)
        return new_article

    async def add_category(self, article_id: int, category_name: str) -> None:
        self.session.add(ArticleCategory(article_id=article_id, category_name=category_name))
