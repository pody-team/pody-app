from datetime import datetime
from typing import Optional

from uuid import uuid4

from sqlalchemy import func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models import Article, ArticleStat, Category, CategoryArticle
from utils.category_slug import build_category_slug


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

    async def add_category(
        self,
        article_id: int,
        category_name: str,
        description: Optional[str] = None,
        is_primary: Optional[bool] = None,
    ) -> None:
        normalized_name = category_name.strip()
        if not normalized_name:
            raise ValueError("category_name is required")

        slug = build_category_slug(normalized_name)
        category_stmt = select(Category).where(
            or_(
                Category.slug == slug,
                func.lower(Category.name) == normalized_name.lower(),
            )
        )
        category_result = await self.session.execute(category_stmt)
        category = category_result.scalar_one_or_none()

        if category is None:
            category = Category(
                id=str(uuid4()),
                slug=slug,
                name=normalized_name,
                description=(description or "").strip() or None,
                is_active=True,
            )
            self.session.add(category)
            await self.session.flush()
        elif description and description.strip() and not category.description:
            category.description = description.strip()
            category.updated_at = datetime.utcnow()

        link_stmt = select(CategoryArticle).where(
            CategoryArticle.article_id == article_id,
            CategoryArticle.category_id == category.id,
            CategoryArticle.assignment_source == "manual",
        )
        link_result = await self.session.execute(link_stmt)
        existing_link = link_result.scalar_one_or_none()

        article_has_category_stmt = (
            select(CategoryArticle.id)
            .where(
                CategoryArticle.article_id == article_id,
                CategoryArticle.assignment_source == "manual",
            )
            .limit(1)
        )
        article_has_category_result = await self.session.execute(article_has_category_stmt)
        article_has_category = article_has_category_result.scalar_one_or_none() is not None

        should_be_primary = is_primary if is_primary is not None else not article_has_category
        if should_be_primary:
            await self.session.execute(
                update(CategoryArticle)
                .where(
                    CategoryArticle.article_id == article_id,
                    CategoryArticle.assignment_source == "manual",
                )
                .values(is_primary=False)
            )

        if existing_link is None:
            self.session.add(
                CategoryArticle(
                    article_id=article_id,
                    category_id=category.id,
                    assignment_source="manual",
                    is_primary=should_be_primary,
                )
            )
            return

        if should_be_primary and not existing_link.is_primary:
            existing_link.is_primary = True
