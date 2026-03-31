import httpx
from typing import Optional
from urllib.parse import urljoin

from bs4 import BeautifulSoup, Tag
from readability import Document

from utils.logger import get_logger


class ContentExtractor:
    _CONTENT_SELECTORS = [
        '[itemprop="articleBody"]',
        '[data-role="content"]',
        '.detail-content',
        '.fck_detail',
        '.content-detail',
        '.article-content',
        '.entry-content',
        '.post-content',
        '.article-body',
        '.news-content',
        'article',
    ]

    def __init__(self):
        self.logger = get_logger(__name__)

    def _cleanup_html(self, container: Tag) -> Optional[str]:
        for tag in container.find_all(['script', 'style']):
            tag.decompose()

        clean_body_html = str(container)
        return clean_body_html if clean_body_html.strip() else None

    def _extract_from_known_containers(self, soup: BeautifulSoup) -> Optional[str]:
        for selector in self._CONTENT_SELECTORS:
            for container in soup.select(selector):
                text = container.get_text(separator=' ', strip=True)
                image_count = len(container.find_all('img'))
                paragraph_count = len(container.find_all('p'))

                if len(text) < 200 and image_count == 0:
                    continue
                if paragraph_count == 0 and image_count == 0:
                    continue

                cleaned = self._cleanup_html(container)
                if cleaned:
                    return cleaned

        return None

    async def fetch_and_extract_content(
        self,
        client: httpx.AsyncClient,
        url: str,
    ) -> Optional[str]:
        """
        Fetch a full article page and return its main body as clean HTML.
        """
        try:
            resp = await client.get(url)
            resp.raise_for_status()
            resp.encoding = 'utf-8'
            html = resp.text
        except Exception as exc:
            self.logger.warning(f"Failed to fetch article page {url}: {exc}")
            return None

        try:
            soup = BeautifulSoup(html, 'html.parser')

            for noscript in soup.find_all('noscript'):
                if noscript.img:
                    noscript.unwrap()

            lazy_attrs = [
                'data-src',
                'data-original',
                'lazy-src',
                'data-lazy',
                'original-src',
                'data-hi-res',
            ]

            for img in soup.find_all('img'):
                real_url = None
                for attr in lazy_attrs:
                    if img.get(attr):
                        real_url = img.get(attr)
                        break

                if not real_url:
                    real_url = img.get('src')

                if real_url:
                    img['src'] = urljoin(url, real_url)
                    img['class'] = 'article-image-confirmed'
                    img['style'] = 'display: block; max-width: 100%; height: auto;'

            # Prefer known article-body containers to preserve inline images.
            direct_content = self._extract_from_known_containers(soup)
            if direct_content:
                return direct_content

            doc = Document(str(soup))
            clean_html = doc.summary()

            body_soup = BeautifulSoup(clean_html, 'html.parser')
            body = body_soup.find('body') or body_soup
            return self._cleanup_html(body)

        except Exception as exc:
            self.logger.warning(f"Content extraction failed for {url}: {exc}")
            return None
