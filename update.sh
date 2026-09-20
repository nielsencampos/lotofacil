#!/usr/bin/env bash
# Fetch every new Lotofacil contest into data/raw/ as JSON.
# Does not touch PostgreSQL — run load.sh afterwards to load the data. Does
# not require Docker/PostgreSQL to be running.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

uv sync --quiet
uv run lotofacil update --skip-load
