import re
import httpx
from typing import List
from urllib.parse import urljoin
from bs4 import BeautifulSoup
from utils.logger import get_logger

# Patterns that suggest a URL is an RSS/Atom feed
_RSS_URL_PATTERNS = [
    re.compile(r'\.rss(?:\?.*)?$', re.IGNORECASE),
    re.compile(r'\.atom(?:\?.*)?$', re.IGNORECASE),
    re.compile(r'/rss/', re.IGNORECASE),
    re.compile(r'/rss$', re.IGNORECASE),
    re.compile(r'/feed/', re.IGNORECASE),
    re.compile(r'/feed$', re.IGNORECASE),
    re.compile(r'/feeds/', re.IGNORECASE),
    re.compile(r'/feeds$', re.IGNORECASE),
    re.compile(r'[?&]format=rss', re.IGNORECASE),
    re.compile(r'[?&]type=rss', re.IGNORECASE),
]

def is_rss_url(url: str) -> bool:
    """Return True if the URL looks like an RSS/Atom feed."""
    return any(p.search(url) for p in _RSS_URL_PATTERNS)

class FeedDiscovery:
    def __init__(self):
        self.logger = get_logger(__name__)

    async def discover_rss_feeds(
        self,
        client: httpx.AsyncClient,
        rss_page_url: str,
        semaphore: any, # Using any for simplicity in typing here, it's asyncio.Semaphore
    ) -> List[str]:
        """
        Fetch the RSS hub page and extract all RSS/Atom feed URLs.
        """
        async with semaphore:
            try:
                resp = await client.get(rss_page_url)
                resp.raise_for_status()
                html = resp.text
            except Exception as exc:
                self.logger.warning(f"Could not fetch RSS hub {rss_page_url}: {exc}")
                return []

        soup = BeautifulSoup(html, 'lxml')
        discovered: set[str] = set()

        # Strategy 1 – <link> tags with RSS/Atom MIME type
        for tag in soup.find_all(
            'link',
            type=re.compile(r'application/(rss|atom)\+xml', re.IGNORECASE),
        ):
            href = tag.get('href', '').strip()
            if href:
                discovered.add(urljoin(rss_page_url, href))

        # Strategy 2 – <a> anchor tags pointing to RSS-like URLs
        for tag in soup.find_all('a', href=True):
            href = tag['href'].strip()
            if not href or href.startswith('#'):
                continue
            full_url = urljoin(rss_page_url, href)
            if is_rss_url(full_url):
                discovered.add(full_url)

        self.logger.debug(
            f"Discovered {len(discovered)} feed(s) from hub: {rss_page_url}"
        )
        return list(discovered)
