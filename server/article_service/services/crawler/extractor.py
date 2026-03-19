import httpx
from typing import Optional
from urllib.parse import urljoin
from bs4 import BeautifulSoup
from readability import Document
from utils.logger import get_logger

class ContentExtractor:
    def __init__(self):
        self.logger = get_logger(__name__)

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
            # Force UTF-8 to avoid garbled Vietnamese / non-ASCII text
            resp.encoding = 'utf-8'
            html = resp.text
        except Exception as exc:
            self.logger.warning(f"Failed to fetch article page {url}: {exc}")
            return None

        try:
            soup = BeautifulSoup(html, 'html.parser')
            
            # GIẢI PHÓNG NỘI DUNG TRONG NOSCRIPT
            for noscript in soup.find_all('noscript'):
                if noscript.img:
                    noscript.unwrap()

            # XỬ LÝ ẢNH VỚI CHIẾN THUẬT "DÒ TÌM" (UNIVERSAL)
            lazy_attrs = ['data-src', 'data-original', 'lazy-src', 'data-lazy', 'original-src', 'data-hi-res']

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
                    img['class'] = "article-image-confirmed"
                    img['style'] = "display: block;"

            # Readability: isolate main article content
            doc = Document(str(soup))
            clean_html = doc.summary()

            # Trích xuất phần <body> từ HTML sạch của Readability
            body_soup = BeautifulSoup(clean_html, 'html.parser')
            body = body_soup.find('body') or body_soup

            # Loại bỏ các thẻ script/style thừa nếu còn sót
            for tag in body.find_all(['script', 'style']):
                tag.decompose()

            clean_body_html = str(body)
            return clean_body_html if clean_body_html.strip() else None

        except Exception as exc:
            self.logger.warning(f"Content extraction failed for {url}: {exc}")
            return None
