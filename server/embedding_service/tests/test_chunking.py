import unittest

from app.util.chunking import build_article_chunks


class ChunkingTests(unittest.TestCase):
    def test_build_article_chunks_includes_title_summary_and_body(self):
        chunks = build_article_chunks(
            title="Tieu de bai viet",
            summary="Tom tat ngan",
            content="Doan mot. " * 120,
            target_chars=300,
            overlap_chars=40,
            min_chunk_chars=80,
        )

        self.assertEqual(chunks[0].chunk_type, "title")
        self.assertTrue(any(chunk.chunk_type == "summary" for chunk in chunks))
        self.assertTrue(any(chunk.chunk_type == "body" for chunk in chunks))
        self.assertTrue(all(chunk.char_count > 0 for chunk in chunks))

    def test_build_article_chunks_skips_duplicate_summary(self):
        chunks = build_article_chunks(
            title="Trung lap",
            summary="Trung lap",
            content="",
            target_chars=300,
            overlap_chars=40,
            min_chunk_chars=80,
        )

        self.assertEqual(len(chunks), 1)
        self.assertEqual(chunks[0].chunk_type, "title")


if __name__ == "__main__":
    unittest.main()
