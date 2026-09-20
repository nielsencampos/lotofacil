"""Load raw JSON draw files from disk into the PostgreSQL `transient.raw` table."""

from __future__ import annotations

import json
from pathlib import Path

from lotofacil.db import get_connection, init_schema
from lotofacil.settings import settings


def _strip_null_bytes(value):
    """Recursively remove NUL characters, which PostgreSQL's JSONB type rejects."""
    if isinstance(value, str):
        return value.replace("\x00", "")
    if isinstance(value, dict):
        return {key: _strip_null_bytes(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_strip_null_bytes(item) for item in value]
    return value


_UPSERT_SQL = """
    INSERT INTO transient.raw (contest_number, payload)
    VALUES (%(contest_number)s, %(payload)s)
    ON CONFLICT (contest_number)
    DO UPDATE SET payload = EXCLUDED.payload, fetched_at = now()
"""


def load_file(path: Path) -> int:
    """Load a single JSON file into `transient.raw`. Returns the contest number loaded."""
    payload = _strip_null_bytes(json.loads(path.read_text(encoding="utf-8")))
    contest_number = int(payload["numero"])

    params = {"contest_number": contest_number, "payload": json.dumps(payload)}
    with get_connection() as conn:
        conn.execute(_UPSERT_SQL, params)
        conn.commit()

    return contest_number


def load_directory(data_dir: Path | None = None) -> list[int]:
    """Load every `*.json` file in `data_dir` into `transient.raw`."""
    data_dir = data_dir or settings.lotofacil_data_dir
    init_schema()

    loaded: list[int] = []
    for path in sorted(data_dir.glob("*.json")):
        loaded.append(load_file(path))

    return loaded
