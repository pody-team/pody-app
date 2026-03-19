"""
Repositories package - Data Access Layer
"""
from .news_source_repository import NewsSourceRepository
from .article_repository import ArticleRepository

__all__ = ['NewsSourceRepository', 'ArticleRepository']
