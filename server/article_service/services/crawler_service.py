"""
Crawler Service - lop wrapper giu tuong thich.
File nay lam facade cho cac module crawler da tach trong package 'crawler'.
"""

from .crawler.engine import CrawlerEngine

class CrawlerService(CrawlerEngine):
    """
    Facade giu tuong thich cho crawler engine.

    Cac module cu van import CrawlerService, con implementation nam trong
    services.crawler.* de tach rieng discovery, extraction, metadata va storage.
    """
    def __init__(self):
        super().__init__()
