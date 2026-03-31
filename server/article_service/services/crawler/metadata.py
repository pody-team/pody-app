import html
import time
from datetime import datetime
from typing import Optional
from bs4 import BeautifulSoup
import feedparser

class MetadataParser:
    @staticmethod
    def normalize_text(value: Optional[str]) -> Optional[str]:
        """Decode HTML entities/tags and normalize whitespace."""
        if not value:
            return None

        text = html.unescape(value)
        text = BeautifulSoup(text, 'lxml').get_text(separator=' ').strip()
        text = ' '.join(text.split())
        return text or None

    @staticmethod
    def extract_thumbnail(entry: feedparser.FeedParserDict) -> Optional[str]:
        """Extract a cover image URL from an RSS/Atom entry."""
        # 1. RSS <enclosure>
        for enc in entry.get('enclosures', []):
            mime = enc.get('type', '')
            url = enc.get('url') or enc.get('href', '')
            if url and mime.startswith('image'):
                return url.strip()

        # 2. <media:thumbnail>
        for thumb in entry.get('media_thumbnail', []):
            url = thumb.get('url', '').strip()
            if url:
                return url

        # 3. <media:content medium="image">
        for mc in entry.get('media_content', []):
            url = mc.get('url', '').strip()
            medium = mc.get('medium', '')
            mime = mc.get('type', '')
            if url and (medium == 'image' or mime.startswith('image')):
                return url

        # 4. First <img> in description/summary HTML
        raw_html = entry.get('summary') or entry.get('description') or ''
        if raw_html:
            soup = BeautifulSoup(raw_html, 'lxml')
            img = soup.find('img', src=True)
            if img:
                src = img['src'].strip()
                if src and not src.startswith('data:'):
                    return src
        return None

    @staticmethod
    def extract_author(entry: feedparser.FeedParserDict) -> Optional[str]:
        """Return the author name from a feedparser entry."""
        author = getattr(entry, 'author', None) or entry.get('author')
        if author and isinstance(author, str):
            return MetadataParser.normalize_text(author)
        authors = getattr(entry, 'authors', None) or entry.get('authors', [])
        if authors:
            name = authors[0].get('name', '')
            return MetadataParser.normalize_text(name)
        return None

    @staticmethod
    def parse_date(entry: feedparser.FeedParserDict) -> Optional[datetime]:
        """Return the publication datetime."""
        for field in ('published_parsed', 'updated_parsed', 'created_parsed'):
            struct = getattr(entry, field, None) or entry.get(field)
            if struct:
                try:
                    return datetime.fromtimestamp(time.mktime(struct))
                except (OverflowError, ValueError):
                    continue
        return None

    @staticmethod
    def extract_summary(entry: feedparser.FeedParserDict) -> Optional[str]:
        """Return a plain-text summary capped at 1000 characters."""
        raw = entry.get('summary') or entry.get('description') or ''
        if not raw:
            return None
        text = MetadataParser.normalize_text(raw)
        return text[:1000] if text else None
