from __future__ import annotations

from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

from app.config.settings import DatabaseSettings


def create_pool(settings: DatabaseSettings) -> ConnectionPool:
    return ConnectionPool(
        conninfo=settings.url,
        min_size=settings.pool_min_size,
        max_size=settings.pool_max_size,
        open=False,
        kwargs={"row_factory": dict_row},
    )
