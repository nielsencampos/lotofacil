# lotofacil

[![CI](https://github.com/nielsencampos/lotofacil/actions/workflows/ci.yml/badge.svg)](https://github.com/nielsencampos/lotofacil/actions/workflows/ci.yml)
![Python 3.12+](https://img.shields.io/badge/python-3.12+-blue.svg)
![dbt](https://img.shields.io/badge/dbt-1.12+-FF694B.svg?logo=dbt&logoColor=white)
![PostgreSQL 16](https://img.shields.io/badge/PostgreSQL-16-4169E1.svg?logo=postgresql&logoColor=white)
[![Ruff](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)](https://github.com/astral-sh/ruff)
[![uv](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/uv/main/assets/badge/v0.json)](https://github.com/astral-sh/uv)
![Claude](https://img.shields.io/badge/Claude-claude--code-D97757?logo=anthropic&logoColor=white)

Data pipeline for Lotofacil (a Brazilian lottery) with insights.

It fetches draw results from the public Caixa API, stores the raw responses
as JSON, loads them into PostgreSQL, and models them with dbt: a typed
`bronze` layer, a `silver` star schema (dimensions and facts) and a `gold`
layer of five tables shaped for a reader (one wide cube per contest, contest
similarity, ball frequency, ball gap and ball quintets). See
[ROADMAP.md](ROADMAP.md) for what comes next.

## Architecture

```
Caixa API  -->  data/raw/*.json  -->  transient.raw (Postgres)  -->  bronze  -->  silver  -->  gold
   (update.sh)                          (load.sh)                       (dbt)      (dbt)     (dbt)
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
    etc). Fields that carry no information (always null, always the same
    value, or redundant with `contest_number`) are dropped — the reasons are
    listed in the header of `dbt/models/bronze/draws.sql`.
  - `ball_draws`, `prize_tiers`, `winning_municipalities`: each unnests one
    of the payload's list/object attributes. `listaDezenas` (redundant with
    `dezenasSorteadasOrdemSorteio`) and the list attributes that are always
    empty/null (`listaDezenasSegundoSorteio`, `listaResultadoEquipeEsportiva`)
    are skipped.
  - `ball_names`, `ball_orders` (dbt seeds): static dictionaries unrelated
    to any specific contest — ball number (1-25) -> name, and draw position
    (1-15) -> name. `ball_draws` joins to both.
  - `holidays` (dbt seed): Brazilian national holidays from 2003 through next
    year, feeding `dim_date`. It is generated from BrasilAPI
    (`uv run lotofacil holidays`) and committed, so builds need no network;
    re-run it about once a year to extend the calendar.

  Every bronze table/seed has a primary key enforced in PostgreSQL (a
  post-hook `alter table` after each build — see `dbt/dbt_project.yml` and
  the `config(post_hook=...)` in each model). Composite keys are verified by
  a small custom generic test (`unique_combination_of_columns`, in
  `dbt/macros/`) since dbt's built-in `unique` test only covers one column.
  Bronze has no foreign keys; the silver layer does (below).
  Every table/column has an English description in the dbt yml files, and
  `persist_docs` writes them into PostgreSQL as real `COMMENT ON
  TABLE`/`COMMENT ON COLUMN` (visible via `\d+` in psql). `transient.raw`
  isn't dbt-managed, so its comments are set directly in `sql/schema.sql`.

- **dbt (silver layer)**: a star schema built from bronze, cleaned and
  renamed with the thesaurus below.

  ```mermaid
  erDiagram
      dim_contest }o--|| dim_location : dim_location_id
      dim_contest }o--|| dim_date : "draw_dim_date_id"
      dim_contest }o--|| dim_date : "next_draw_dim_date_id"
      fact_contest_summary ||--|| dim_contest : dim_contest_id
      fact_ball_draws }o--|| dim_contest : dim_contest_id
      fact_ball_draws }o--|| dim_draw_position : dim_draw_position_id
      fact_ball_draws }o--|| dim_ball : dim_ball_id
      fact_prize_tiers }o--|| dim_contest : dim_contest_id
      fact_prize_tiers }o--|| dim_prize_tier : dim_prize_tier_id
      fact_winning_municipalities }o--|| dim_contest : dim_contest_id
      fact_winning_municipalities }o--|| dim_location : dim_location_id
  ```

  - **Keys**: every dimension has a `dim_*_id` primary key and every fact a
    `fact_*_id`; facts reference dimensions only through `dim_*_id` (no raw
    dates, no repeated names). The natural key of each table stays enforced
    as `UNIQUE`. Ids are the natural number when there is one
    (`dim_contest_id` = contest number, `dim_ball_id` = ball number),
    `yyyymmdd` for `dim_date_id`, and a deterministic numeric md5 of the
    natural key for `dim_location_id` and the `fact_*_id`s
    (`dbt/macros/numeric_md5.sql`) — unlike `row_number()` they don't shift
    between rebuilds, and they stay under 2^53 so JavaScript/Excel/BI tools
    don't round them. Each `fact_*_id` hashes the grain only (e.g.
    contest + draw position, not the ball), so a corrected result doesn't
    change the row's id.
  - **Import CTEs**: every model brings each table it reads in through its
    own leading `with` CTE (named after the source, selecting only the
    columns used), and joins/aggregates off those CTEs, never off a bare
    `{{ ref(...) }}` inside a `from`/`join`. Keeps each model self-documenting
    about exactly which columns it depends on.
  - **`dim_location`** is shared by draws (venue + city + state) and winning
    tickets (city + state only, venue `---NAO SE APLICA---`).
    **`dim_date`** has one row per calendar day, from the first contest to
    the latest `next_draw_date`, with year/semester/quarter/bimester/month/ISO
    week, Portuguese day and month names, and flags, including national
    holidays (from the `holidays` seed).
    `dim_contest` references it twice (`draw_dim_date_id`,
    `next_draw_dim_date_id`), a role-playing dimension.
  - **Text normalization** (`dbt/macros/normalize_texts.sql`): upper + trim +
    unaccent (Postgres `unaccent`, created by an `on-run-start` hook), blanks
    filled as `---NAO INFORMADO---`, online sales (`--`/`XX`, "canal
    eletrônico") canonicalized to `XX`, truncated states `C`/`G` fixed to
    `CE`/`GO`, and known typos/variants of draw venues mapped to 5 canonical
    venue names (a blank venue is `---NAO INFORMADO---`; winning tickets, which
    have no venue, get `---NAO SE APLICA---`). An `accepted_values` test on `dim_location.location_nm` fails when
    a new, unmapped venue shows up, so it gets a conscious decision. The
    same macros are used by every model that touches these columns —
    otherwise the joins between them would silently stop matching.
  - **Thesaurus** (column suffixes): `_id` key, `_nbr` number, `_nm` name,
    `_cd` code, `_dt` date, `_flg` boolean flag, `_desc` description, `_amt`
    decimal amount, `_qtty` integer quantity, `_pct` percentage (0-100),
    `_avg` decimal average.
  - **Tags** let you select groups of models regardless of folder: `bronze`,
    `silver`, `gold`, `dim`, `fact`, `cube`, `similarity`, `frequency`, `gap`,
    `quintet`, `dictionary` (the seeds), e.g. `dbt run --select tag:dim` or
    `dbt build --select tag:silver,tag:fact`.
  - Primary keys, unique keys and foreign keys are all enforced in
    PostgreSQL by post-hooks. Constraints that create an index are left
    unnamed on purpose: dbt rebuilds a table next to the old one and the
    hook runs before the old one is dropped, so an explicitly named index
    collides (index names are unique per schema).

- **dbt (gold layer)**: tables built only from silver and shaped for a reader
  instead of for modeling, each independent of the others (see the data model
  below). `cube_contest` is one wide row per contest, queried without joins;
  `similar_contests` is a bridge of contest pairs that drew nearly the same
  15 balls; `ball_frequency` is one row per ball with its share of the balls
  drawn, as a percentage, over several windows; `ball_gap` is one row per
  ball with how many contests since it last came out, and how that compares
  with its own history; `ball_quintets` is one row per possible 5-ball
  combination, how many contests drew all 5 together.

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
dbt/                    dbt Core project (bronze + silver + gold models, seeds, macros)
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

uv run lotofacil holidays                       # rebuild dbt/seeds/holidays.csv from BrasilAPI
```

## Data model

| Layer   | Model                       | Grain                                      | Primary key                          |
|---------|-----------------------------|---------------------------------------------|---------------------------------------|
| raw     | `transient.raw`             | one row per contest (JSONB)                  | `contest_number`                      |
| bronze  | `draws`                     | one row per contest, scalar attributes only, typed | `contest_number`                |
| bronze  | `ball_draws`                | one row per contest x draw position (1-15), typed  | `(contest_number, draw_order)`  |
| bronze  | `prize_tiers`               | one row per contest x prize tier, typed      | `(contest_number, prize_tier_number)` |
| bronze  | `winning_municipalities`    | one row per contest x winning municipality, typed | `(contest_number, winner_index)` |
| bronze  | `ball_names` (seed)         | static: one row per ball number (1-25)       | `number`                              |
| bronze  | `ball_orders` (seed)        | static: one row per draw position (1-15)     | `draw_order`                          |
| bronze  | `holidays` (seed)           | static: one row per national holiday date    | `holiday_date`                        |
| silver  | `dim_contest`               | one row per contest                          | `dim_contest_id` (= contest number)   |
| silver  | `dim_location`              | one row per (venue, city, state)             | `dim_location_id` (numeric md5)       |
| silver  | `dim_date`                  | one row per calendar day                     | `dim_date_id` (`yyyymmdd`)            |
| silver  | `dim_ball`                  | one row per ball number (1-25)               | `dim_ball_id`                         |
| silver  | `dim_draw_position`         | one row per draw position (1-15)             | `dim_draw_position_id`                |
| silver  | `dim_prize_tier`            | one row per prize tier (5)                   | `dim_prize_tier_id` (= hits, 11-15)   |
| silver  | `fact_contest_summary`      | one row per contest (monetary measures)      | `fact_contest_summary_id`             |
| silver  | `fact_ball_draws`           | one row per contest x draw position          | `fact_ball_draw_id`                   |
| silver  | `fact_prize_tiers`          | one row per contest x prize tier             | `fact_prize_tier_id`                  |
| silver  | `fact_winning_municipalities` | one row per contest x winning municipality | `fact_winning_municipality_id`        |

Gold is the consumption layer: tables shaped for a reader, built only from
silver, with no key of their own beyond the natural one.

| Layer   | Model                       | Grain                                      | Primary key                          |
|---------|-----------------------------|---------------------------------------------|---------------------------------------|
| gold    | `cube_contest`              | one row per contest, everything in one place | `contest_nbr`                         |
| gold    | `similar_contests`          | one row per pair of contests sharing 13+ balls | `(contest_a_nbr, contest_b_nbr)`   |
| gold    | `ball_frequency`            | one row per ball (1-25)                      | `ball_nbr`                            |
| gold    | `ball_gap`                  | one row per ball (1-25)                      | `ball_nbr`                            |
| gold    | `ball_quintets`              | one row per possible 5-ball combination     | `(ball_1_nbr .. ball_5_nbr)`          |

`cube_contest` carries the draw date and place, the drawn balls as two integer
arrays (`balls_draw_order` in the order they came out, `balls_sorted` in numeric
order), the winners and prize of each tier (`tier_15_*` ... `tier_11_*`), the
winning municipalities of the 15-hit tier (`tier_15_winning_locations`, a JSON
array; the source doesn't label the tier, but the list only exists for contests
with a 15-hit winner, and tiers 11-14 have no location data), and the money
measures. Because those municipalities' winners don't always add up to
`tier_15_winner_qtty` in the source (79 contests differ), both are shown as sent
rather than reconciled.

`similar_contests` finds contests whose 15 drawn balls nearly or exactly match
another contest's, `contest_a_nbr` always the earlier one. The cut is 13+
shared balls, not the lowest prize tier (11): two random contests already
share ~9 balls by chance, so 11+ is already ~11% of the ~7.2M possible pairs
(760k of them) and not meaningfully similar, while 13+ is a ~10.7k-row tail
worth looking at (354 pairs share 14; none share all 15, yet). Draw date,
venue (`location_nm`/`city_nm`/`state_cd`) and the tier-15 winner info
(`tier_15_winner_qtty`, `tier_15_winning_municipality_qtty`,
`tier_15_winning_locations`) are unfolded per contest
(`contest_a_*`/`contest_b_*`) the same way `cube_contest` unfolds them, so
the pair reads without a join back to it.

`ball_frequency` has, per ball, its share of the balls drawn (not of the
contests) over a set of cumulative windows by draw order -- the last 1
(`last_contest_pct`, necessarily 0 or 100/15 = 6.6667 since one draw picks 15
of the 25 balls), 2, 3, 5, 10, 15 and 25 contests taken together
(`last_2_contests_pct` is the last 2 contests as a whole, not the
second-to-last contest alone; same pattern through `last_25_contests_pct`) --
plus the last 1/2/3/5/10 calendar years back from the most recent draw
(`last_1_year_pct` ... `last_10_years_pct`) and the whole history
(`total_pct`). Each window's 25 percentages always sum to 100.

`ball_gap` has, per ball, `current_gap_qtty` (contests since its last
appearance, 0 if it came out in the most recent contest) next to
`max_gap_qtty` and `avg_gap_avg` (the longest and average gap it has ever had
between two consecutive appearances), so a reader can tell whether the
current dry spell is unusual for that ball. `max_gap_qtty`/`avg_gap_avg` only
count closed gaps, so a ball can be mid-record (`current_gap_qtty` bigger
than its own `max_gap_qtty`) until that gap closes.

`ball_quintets` has one row per possible 5-ball combination out of the 25
(C(25,5) = 53,130), with `together_qtty`/`together_pct`: how many contests
(and what share) drew all 5 of them together. 5, not 2, because two 15-of-25
draws always share at least 15 + 15 - 25 = 5 balls -- a mathematical floor,
not a coincidence -- which makes a specific quintet's ~5.65%-per-contest
chance a more meaningful unit to look at than a pair's ~35% (close to
uniform across all 300 pairs, mostly noise). Every combination is included,
even ones that never happened (`together_qtty = 0`), not just the observed
ones.

## Notebooks

Ad-hoc exploration happens in Jupyter, in the `workspace/` directory:

```bash
uv sync --group notebook
uv run jupyter lab --notebook-dir=workspace
```

`workspace/` is excluded from linting (see below) since notebooks aren't
held to the same style as the package code. `pandas` and `itables` (paginated,
searchable tables) are part of the `notebook` group.

Two gotchas when exploring the database from a notebook:

- `psycopg` opens a transaction on the first query, and an open transaction
  keeps a lock on the tables it read. That blocks `dbt run` (it needs an
  exclusive lock to swap a table). Use `psycopg.connect(..., autocommit=True)`
  or call `conn.commit()` after your queries.
- `load.sh`/`update.sh` sync with `uv sync --inexact`, so they don't remove
  the `notebook` group; a plain `uv sync` does.

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

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md)
for the workflow, [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for expected
behavior, and [SECURITY.md](SECURITY.md) to report a vulnerability privately.

## License

MIT — see [LICENSE](LICENSE).

---

Built with [Claude Code](https://claude.ai/code) by [Anthropic](https://anthropic.com).
