from __future__ import annotations

from contextlib import contextmanager

from psycopg_pool import ConnectionPool

from app.model.entity import CategoryCatalogItem


class CategoryCatalogRepository:
    """Repository doc category tu database nguon cua article_service."""

    def __init__(self, pool: ConnectionPool) -> None:
        self._pool = pool

    @contextmanager
    def _connection(self):
        """Lay connection tu pool nguon category."""
        with self._pool.connection() as conn:
            yield conn

    def ping(self) -> bool:
        """Kiem tra database category source co san sang khong."""
        try:
            with self._connection() as conn:
                conn.execute("SELECT 1").fetchone()
            return True
        except Exception:
            return False

    def list_categories(self) -> list[CategoryCatalogItem]:
        """Lay toan bo category de bootstrap embedding catalog."""
        with self._connection() as conn:
            rows = conn.execute(
                """
                SELECT
                    id::text AS category_id,
                    slug,
                    name,
                    description,
                    is_active,
                    created_at,
                    updated_at
                FROM categories
                ORDER BY name ASC, slug ASC
                """
            ).fetchall()
        return [CategoryCatalogItem.from_row(row) for row in rows]
