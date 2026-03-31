import unittest

from app.model.request import parse_article_search_request
from app.model.response import ArticleSearchMatchResponse, ArticleSearchResponse
from app.view import ArticleSearchView


class SearchContractsTests(unittest.TestCase):
    def test_parse_article_search_request_clamps_limit(self):
        request = parse_article_search_request({"query": " kinh te ", "limit": 99})

        self.assertEqual(request.query, "kinh te")
        self.assertEqual(request.limit, 20)

    def test_article_search_view_renders_expected_payload(self):
        response = ArticleSearchResponse(
            query="kinh te",
            limit=2,
            matches=[
                ArticleSearchMatchResponse(
                    article_id=11,
                    title="Tin kinh te",
                    original_url="https://example.com/11",
                    chunk_index=0,
                    chunk_type="title",
                    chunk_preview="Tin kinh te",
                    score=0.91,
                )
            ],
        )

        payload = ArticleSearchView().render_search_results(response)

        self.assertEqual(payload["query"], "kinh te")
        self.assertEqual(payload["matches"][0]["article_id"], 11)
        self.assertEqual(payload["matches"][0]["chunk_type"], "title")


if __name__ == "__main__":
    unittest.main()
