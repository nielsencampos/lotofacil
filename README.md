# lotofacil

Data pipeline for Lotofacil (a Brazilian lottery) with insights.

It fetches draw results from the public Caixa API, stores the raw responses
as JSON, loads them into PostgreSQL, and turns them into typed tables with
dbt.

## Architecture

```
Caixa API  -->  data/raw/*.json  -->  transient.raw (Postgres)  -->  bronze
   (update.sh)                          (load.sh)
```

- **Source**: `https://servicebus2.caixa.gov.br/portaldeloterias/api/lotofacil/{contest_number}`
  (omit the contest number to get the latest draw; a non-existent contest
  number returns an HTTP error).
- **`data/raw/`**: one JSON file per contest (e.g. `data/raw/1.json`,
  `data/raw/2.json`, ...), kept as the raw, versioned source of truth. There
  is no "list all contests" endpoint, so the updater walks contest numbers
  upward starting at 1 and stops as soon as the API errors out on a number
  that doesn't exist yet.
- **PostgreSQL**: runs in Docker. `transient.raw` stores each contest's
  untouched JSON payload in a `JSONB` column, keyed by contest number.
- **dbt (bronze layer)**: one table per JSON attribute that holds real data —
  typed and renamed to English, but with no business logic, joins, or
  derived columns:
  - `draws`: every scalar attribute of the payload (dates, amounts, flags,
    etc). Fields that are always null or redundant with `contest_number`
    are dropped.
  - `ball_draws`, `prize_tiers`, `winning_municipalities`: each unnests one
    of the payload's list/object attributes. `listaDezenas` (redundant with
    `dezenasSorteadasOrdemSorteio`) and the list attributes that are always
    empty/null (`listaDezenasSegundoSorteio`, `listaResultadoEquipeEsportiva`)
    are skipped.
  - `ball_names`, `ball_orders` (dbt seeds): static dictionaries unrelated
    to any specific contest — ball number (1-25) -> name, and draw position
    (1-15) -> name. `ball_draws` joins to both.

  Every bronze table/seed has a primary key enforced in PostgreSQL (a
  post-hook `alter table` after each build — see `dbt/dbt_project.yml` and
  the `config(post_hook=...)` in each model). Composite keys are verified by
  a small custom generic test (`unique_combination_of_columns`, in
  `dbt/macros/`) since dbt's built-in `unique` test only covers one column.
  No foreign keys yet — there's nothing downstream of bronze to reference.
  Every table/column has an English description in the dbt yml files, and
  `persist_docs` writes them into PostgreSQL as real `COMMENT ON
  TABLE`/`COMMENT ON COLUMN` (visible via `\d+` in psql). `transient.raw`
  isn't dbt-managed, so its comments are set directly in `sql/schema.sql`.

Fetching and loading are two independent services: `update.sh` only talks to
the Caixa API and writes to `data/raw/` (no Docker/PostgreSQL needed);
`load.sh` only reads `data/raw/` and writes to PostgreSQL. Only PostgreSQL
runs in Docker — the Python pipeline and dbt run locally via
[uv](https://docs.astral.sh/uv/), connecting to the database through the
port Docker publishes on `localhost`.

Since `data/raw/` is the source of truth and nothing in Postgres is
incremental (every bronze table/seed is fully rebuilt on every run), it's
safe to kill PostgreSQL whenever it's not needed
(`docker compose down -v` wipes it, volume included) and bring it back with
`./rebuild.sh` — no state is lost.

## Project layout

```
data/raw/               Raw JSON files fetched from the API (1.json, 2.json, ...)
src/lotofacil/          Python package: API client, fetch/load logic, CLI
sql/schema.sql          transient.raw table DDL
dbt/                    dbt Core project (bronze models + seeds)
docker-compose.yml      PostgreSQL service
update.sh               Fetches new contests into data/raw/ (no Docker needed)
load.sh                 Loads data/raw/ into PostgreSQL's transient.raw
rebuild.sh              load.sh + dbt seed/run/test — full rebuild in one step
workspace/              Jupyter notebooks for ad-hoc exploration (not linted)
.github/workflows/      CI (lint + dbt build/test)
.actrc                  Pins the runner image for local CI runs via act
.env                    Local credentials/host config (gitignored)
```

## Requirements

- Docker and Docker Compose (for PostgreSQL)
- [uv](https://docs.astral.sh/uv/) (runs the Python pipeline and dbt)

## Getting started

1. Copy the environment file and adjust it if needed:

   ```bash
   cp .env.example .env
   ```

   `.env` holds the database credentials/host and is gitignored — never
   commit it.

2. Fetch new contests:

   ```bash
   ./update.sh
   ```

   Fetches every contest not yet in `data/raw/` (starting from 1 the first
   time) and stops as soon as the API has no more data. Run it again any
   time to pick up newly drawn contests. Does not require PostgreSQL.

3. Load them into PostgreSQL and build the bronze models:

   ```bash
   ./rebuild.sh
   ```

   Starts the `db` container (if it isn't already running), creates the
   `transient.raw` schema/table, (re)loads every JSON file in `data/raw/`,
   then runs `dbt seed`, `dbt run`, and `dbt test`. Safe to re-run any time,
   including right after killing PostgreSQL entirely — see below.

## CLI reference

`update.sh`/`load.sh`/`rebuild.sh` wrap the common cases, but each step is
also available directly via `uv run lotofacil <command>`:

```bash
uv run lotofacil init-db                        # create the transient.raw schema/table
uv run lotofacil update                         # fetch new contests + load them
uv run lotofacil update --skip-load             # fetch new contests only (what update.sh runs)

uv run lotofacil fetch --contest 3783           # fetch one specific contest
uv run lotofacil fetch --start 3700 --end 3783  # fetch a specific range
uv run lotofacil fetch --latest                 # fetch only the most recent contest

uv run lotofacil load                           # (re)load every JSON file in data/raw/ (what load.sh runs)
```

## Data model

| Layer   | Model                       | Grain                                      | Primary key                          |
|---------|-----------------------------|---------------------------------------------|---------------------------------------|
| raw     | `transient.raw`             | one row per contest (JSONB)                  | `contest_number`                      |
| bronze  | `draws`                     | one row per contest, scalar attributes only, typed | `contest_number`                |
| bronze  | `ball_draws`                | one row per contest x draw position (1-15), typed  | `(contest_number, draw_order)`  |
| bronze  | `prize_tiers`               | one row per contest x prize tier, typed      | `(contest_number, prize_tier)`        |
| bronze  | `winning_municipalities`    | one row per contest x winning municipality, typed | `(contest_number, winner_index)` |
| bronze  | `ball_names` (seed)         | static: one row per ball number (1-25)       | `number`                              |
| bronze  | `ball_orders` (seed)        | static: one row per draw position (1-15)     | `draw_order`                          |

Staging/mart models (typed joins, fact tables, aggregations) don't exist yet
— they're the natural next step on top of this bronze layer.

## Notebooks

Ad-hoc exploration happens in Jupyter, in the `workspace/` directory:

```bash
uv sync --group notebook
uv run jupyter lab --notebook-dir=workspace
```

`workspace/` is excluded from linting (see below) since notebooks aren't
held to the same style as the package code.

## Linting

```bash
uv run ruff check src/
```

Ruff enforces a 100-character line length. `data/` (raw JSON) and
`workspace/` (notebooks) are excluded.

## CI

`.github/workflows/ci.yml` runs on every push to `main` (including a PR
merge, once this project starts using PRs — right now we commit to `main`
directly). It does not run on PR open/sync events.

- **lint**: `uv run ruff check src/`.
- **dbt**: starts a `postgres:16-alpine` service container, then runs
  `lotofacil init-db` + `lotofacil load` (loading the JSON files already
  committed under `data/raw/` — no calls to the Caixa API) followed by
  `dbt seed`, `dbt run`, and `dbt test`.

### Running it locally with `act`

[`act`](https://github.com/nektos/act) runs GitHub Actions workflows locally
in Docker, so you can validate CI changes before pushing:

```bash
act -l              # list the jobs act discovers
act -j lint
act -j dbt
```

`.actrc` pins the runner image (`catthehacker/ubuntu:act-latest`) so `act`
doesn't prompt you to pick one. Note: `act`'s runner images bundle Node.js
because most GitHub Actions (like `actions/checkout`) are implemented in
JS — that's expected, not a sign something's misconfigured.

The `dbt` job's Postgres service binds host port 5432, same as our own `db`
container — stop it first (`docker compose stop db`) or `act` will fail with
"port is already allocated". Bring it back with `docker compose up -d db`.

## Dependabot

`.github/dependabot.yml` keeps three ecosystems up to date on a weekly
schedule: `pip` (`pyproject.toml`/`uv.lock`), `github-actions`
(`.github/workflows/`), and `docker-compose` (the Postgres image). It runs
on GitHub's own infrastructure, not in CI.

It can also be dry-run locally with the
[Dependabot CLI](https://github.com/dependabot/cli) (also Docker-based, like
`act`), which is how the `actions/checkout`/`astral-sh/setup-uv` versions in
`ci.yml` were found to be outdated:

```bash
export LOCAL_GITHUB_ACCESS_TOKEN=$(gh auth token)
dependabot update github_actions <owner>/<repo> --local .
```

`--local .` points it at the working directory instead of cloning the repo,
so it reflects uncommitted changes. It prints what PR it *would* open
without actually opening one.
