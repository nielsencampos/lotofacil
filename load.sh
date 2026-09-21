#!/usr/bin/env bash
# Bring up the PostgreSQL container (if needed), then load every JSON file
# in data/raw/ into transient.raw. Run update.sh first to fetch new contests.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

docker compose up -d --wait db

uv sync --quiet --inexact
uv run lotofacil init-db
uv run lotofacil load
