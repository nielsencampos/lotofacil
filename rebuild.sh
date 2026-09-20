#!/usr/bin/env bash
# Rebuild everything from data/raw/: brings PostgreSQL up (if needed), loads
# every JSON file, and builds the bronze dbt models/seeds. Safe to run any
# time, including right after `docker compose down -v` — data/raw/ is the
# source of truth and nothing in Postgres is incremental, so it's fine to
# kill the database whenever it's not needed and rebuild it on demand.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

./load.sh

uv run dbt seed --project-dir dbt --profiles-dir dbt
uv run dbt run --project-dir dbt --profiles-dir dbt
uv run dbt test --project-dir dbt --profiles-dir dbt
