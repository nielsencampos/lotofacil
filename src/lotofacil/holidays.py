"""Build the `holidays` dbt seed from BrasilAPI's Brazilian national holiday calendar.

Example endpoint: https://brasilapi.com.br/api/feriados/v1/2024

The seed is committed, so `dbt seed` never needs the network; run `lotofacil holidays`
whenever the calendar needs to grow (roughly once a year).
"""

from __future__ import annotations

import csv
import unicodedata
from datetime import UTC, datetime
from pathlib import Path

import httpx

from lotofacil.settings import settings

_TIMEOUT = 30.0

# The first Lotofacil contest was drawn in 2003, and dim_date starts on that day.
FIRST_YEAR = 2003


def fetch_holidays(year: int) -> list[dict]:
    """Fetch the national holidays of one year, as returned by BrasilAPI."""
    response = httpx.get(
        f"{settings.holidays_api_base_url}/{year}", timeout=_TIMEOUT, follow_redirects=True
    )
    response.raise_for_status()
    return response.json()


def _normalize(text: str) -> str:
    """Upper case and unaccented, like the rest of the text in bronze/silver."""
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return ascii_text.strip().upper()


def build_rows(start_year: int, end_year: int) -> list[tuple[str, str]]:
    """Return (holiday_date, holiday_name) rows, one per date, sorted by date.

    Two holidays can fall on the same day (Easter and Tiradentes in 2019), and the seed
    is keyed by date, so their names are joined with " / " instead of dropping one.
    """
    names_by_date: dict[str, list[str]] = {}
    for year in range(start_year, end_year + 1):
        for holiday in fetch_holidays(year):
            names = names_by_date.setdefault(holiday["date"], [])
            name = _normalize(holiday["name"])
            if name not in names:
                names.append(name)
    return [(day, " / ".join(sorted(names))) for day, names in sorted(names_by_date.items())]


def write_seed(
    start_year: int = FIRST_YEAR,
    end_year: int | None = None,
    output: Path | None = None,
) -> tuple[Path, int]:
    """Write the seed CSV and return its path and number of rows.

    `end_year` defaults to next year, so the seed still covers dim_date once its last
    date (the next scheduled draw) crosses into January.
    """
    output = output or settings.holidays_seed_path
    end_year = end_year or datetime.now(tz=UTC).year + 1
    rows = build_rows(start_year, end_year)

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file, lineterminator="\n")
        writer.writerow(["holiday_date", "holiday_name"])
        writer.writerows(rows)
    return output, len(rows)
