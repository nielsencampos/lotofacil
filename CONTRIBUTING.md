# Contributing

Thanks for your interest in contributing to this project!

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-username>/lotofacil.git
   cd lotofacil
   ```
3. Install [uv](https://docs.astral.sh/uv/) and sync dependencies:
   ```bash
   uv sync
   ```
4. Copy the environment file and bring the project up:
   ```bash
   cp .env.example .env
   ./rebuild.sh
   ```
   See the [README](README.md) for the full setup and CLI reference.

## Making Changes

- Branch off `main` for your change; keep commits focused on one logical change each.
- Run `uv run ruff check .` before committing — CI enforces it.
- If you touch a dbt model, run `./rebuild.sh` twice (once from scratch, once over
  an already-populated database) so both the build and the `dbt test` suite pass
  in both scenarios.
- Validate CI locally with [`act`](https://github.com/nektos/act) before opening a
  PR (see the README's "Running it locally with act" section) — stop the `db`
  container first (`docker compose stop db`) so `act`'s own Postgres service can
  bind port 5432, and bring it back after (`docker compose up -d db`).

## Submitting a Pull Request

1. Push your branch and open a pull request against `main`.
2. Describe what changed, why, and how you tested it.
3. CI (lint + dbt build/test) must pass before a PR is merged.

## Reporting Bugs or Suggesting Features

Use the issue templates — Bug report or Feature request — when opening an issue.
