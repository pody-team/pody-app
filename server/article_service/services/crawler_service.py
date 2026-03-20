"""
Crawler Service - Compatibility Wrapper.
This file now acts as a facade for the refactored crawler modules in the 'crawler' package.
"""

from .crawler.engine import CrawlerEngine

class CrawlerService(CrawlerEngine):
    """
    Refactored version of CrawlerService inheriting from CrawlerEngine 
    to maintain compatibility with existing imports.
    """
    def __init__(self):
        super().__init__()
