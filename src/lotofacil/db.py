"""PostgreSQL connection helpers."""

from __future__ import annotations

from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

import psycopg

from lotofacil.settings import settings

SCHEMA_SQL_PATH = Path(__file__).resolve().parents[2] / "sql" / "schema.sql"


@contextmanager
def get_connection() -> Iterator[psycopg.Connection]:
    conn = psycopg.connect(settings.database_url)
    try:
        yield conn
    finally:
        conn.close()


def init_schema() -> None:
    """Create the raw schema/table if they do not exist yet."""
    ddl = SCHEMA_SQL_PATH.read_text(encoding="utf-8")
    with get_connection() as conn:
        conn.execute(ddl)
        conn.commit()
