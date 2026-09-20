"""Thin client for the Caixa Lotofacil public API.

Example endpoint: https://servicebus2.caixa.gov.br/portaldeloterias/api/lotofacil/3783
Calling the base URL without a contest number returns the most recent draw.
"""

from __future__ import annotations

import httpx

from lotofacil.settings import settings

_TIMEOUT = 30.0


def fetch_contest(contest_number: int | None = None) -> dict:
    """Fetch a single contest result. Omit `contest_number` to get the latest draw."""
    url = settings.lotofacil_api_base_url
    if contest_number is not None:
        url = f"{url}/{contest_number}"

    response = httpx.get(url, timeout=_TIMEOUT, follow_redirects=True)
    response.raise_for_status()
    return response.json()


def fetch_latest_contest_number() -> int:
    """Return the contest number of the most recent draw."""
    payload = fetch_contest(None)
    return int(payload["numero"])
