"""Fetch Lotofacil draw results from the API and persist them as raw JSON files."""

from __future__ import annotations

import json
import time
from pathlib import Path

import httpx

from lotofacil.api_client import fetch_contest, fetch_latest_contest_number
from lotofacil.settings import settings


def _output_path(contest_number: int, data_dir: Path) -> Path:
    return data_dir / f"{contest_number}.json"


def save_contest(contest_number: int, data_dir: Path | None = None) -> Path:
    """Fetch one contest and save it to `data_dir/<contest_number>.json`."""
    data_dir = data_dir or settings.lotofacil_data_dir
    data_dir.mkdir(parents=True, exist_ok=True)

    payload = fetch_contest(contest_number)
    path = _output_path(contest_number, data_dir)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return path


def save_range(
    start: int,
    end: int,
    data_dir: Path | None = None,
    skip_existing: bool = True,
    delay_seconds: float = 0.2,
) -> list[Path]:
    """Fetch every contest number in `[start, end]` (inclusive) and save each as JSON."""
    data_dir = data_dir or settings.lotofacil_data_dir
    saved: list[Path] = []

    for contest_number in range(start, end + 1):
        path = _output_path(contest_number, data_dir)
        if skip_existing and path.exists():
            continue
        saved.append(save_contest(contest_number, data_dir))
        time.sleep(delay_seconds)

    return saved


def save_latest(data_dir: Path | None = None) -> Path:
    """Fetch the most recent contest and save it as JSON."""
    contest_number = fetch_latest_contest_number()
    return save_contest(contest_number, data_dir)


def _next_contest_number(data_dir: Path) -> int:
    existing = [int(p.stem) for p in data_dir.glob("*.json") if p.stem.isdigit()]
    return max(existing) + 1 if existing else 1


def sync_new_contests(data_dir: Path | None = None, delay_seconds: float = 0.2) -> list[int]:
    """Fetch every contest starting from the next missing number, one by one.

    The API has no "list all contests" endpoint, so this walks contest numbers
    upward starting at whatever comes after the highest one already saved (or
    1 if `data_dir` is empty), stopping as soon as the API errors out on a
    contest number that doesn't exist yet.
    """
    data_dir = data_dir or settings.lotofacil_data_dir
    data_dir.mkdir(parents=True, exist_ok=True)

    contest_number = _next_contest_number(data_dir)
    fetched: list[int] = []

    while True:
        try:
            save_contest(contest_number, data_dir)
        except httpx.HTTPStatusError:
            break
        fetched.append(contest_number)
        contest_number += 1
        time.sleep(delay_seconds)

    return fetched
