"""Command-line interface for the Lotofacil data pipeline."""

from __future__ import annotations

from pathlib import Path

import typer

from lotofacil import fetch as fetch_module
from lotofacil import load as load_module
from lotofacil.db import init_schema

app = typer.Typer(help="Fetch Lotofacil draw results and load them into PostgreSQL.")


@app.command()
def fetch(
    contest: int | None = typer.Option(None, help="Single contest number to fetch."),
    start: int | None = typer.Option(None, help="First contest number of a range to fetch."),
    end: int | None = typer.Option(None, help="Last contest number of a range to fetch."),
    latest: bool = typer.Option(False, help="Fetch only the most recent contest."),
    data_dir: Path | None = typer.Option(None, help="Directory to save JSON files into."),
) -> None:
    """Fetch one contest, a range of contests, or the latest contest from the API."""
    if latest:
        path = fetch_module.save_latest(data_dir)
        typer.echo(f"Saved latest contest to {path}")
    elif contest is not None:
        path = fetch_module.save_contest(contest, data_dir)
        typer.echo(f"Saved contest {contest} to {path}")
    elif start is not None and end is not None:
        paths = fetch_module.save_range(start, end, data_dir)
        typer.echo(f"Saved {len(paths)} contest(s) ({start}-{end}) to {data_dir or 'data/raw'}")
    else:
        raise typer.BadParameter("Provide --latest, --contest, or both --start and --end.")


@app.command()
def load(
    data_dir: Path | None = typer.Option(None, help="Directory to read JSON files from."),
) -> None:
    """Load every JSON file in the data directory into PostgreSQL."""
    loaded = load_module.load_directory(data_dir)
    typer.echo(f"Loaded {len(loaded)} contest(s) into transient.raw")


@app.command("init-db")
def init_db() -> None:
    """Create the raw schema/table in PostgreSQL if they don't already exist."""
    init_schema()
    typer.echo("Schema initialized")


@app.command()
def update(
    data_dir: Path | None = typer.Option(None, help="Directory to save/read JSON files."),
    skip_load: bool = typer.Option(
        False, "--skip-load", help="Only fetch, don't load into PostgreSQL."
    ),
) -> None:
    """Fetch every new contest since the last one saved and load it into PostgreSQL."""
    fetched = fetch_module.sync_new_contests(data_dir)
    if not fetched:
        typer.echo("No new contests found")
        return

    typer.echo(f"Fetched {len(fetched)} new contest(s): {fetched[0]}-{fetched[-1]}")

    if not skip_load:
        loaded = load_module.load_directory(data_dir)
        typer.echo(f"Loaded {len(loaded)} contest(s) into transient.raw")


if __name__ == "__main__":
    app()
