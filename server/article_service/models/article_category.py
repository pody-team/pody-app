"""
Backward-compatible shim.

Use CategoryArticle from category_article.py for new code.
"""
from .category_article import CategoryArticle

ArticleCategory = CategoryArticle

__all__ = ["CategoryArticle", "ArticleCategory"]
