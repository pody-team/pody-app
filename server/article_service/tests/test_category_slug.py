import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from models.article_category import ArticleCategory
from models.category_article import CategoryArticle
from utils.category_slug import build_category_slug


class CategorySlugTests(unittest.TestCase):
    def test_article_category_alias_stays_mapped_to_category_article(self):
        self.assertIs(ArticleCategory, CategoryArticle)

    def test_build_category_slug_normalizes_vietnamese_name(self):
        self.assertEqual(build_category_slug("Cong nghe AI"), "cong-nghe-ai")
        self.assertEqual(build_category_slug("C\u00f4ng ngh\u1ec7 AI"), "cong-nghe-ai")

    def test_build_category_slug_collapses_symbols_and_spaces(self):
        self.assertEqual(build_category_slug("  Kinh_te & Thi truong  "), "kinh-te-thi-truong")


if __name__ == "__main__":
    unittest.main()
