-- Transient landing zone: one row per contest, holding the untouched API payload.
-- dbt's bronze models read from this table.
CREATE SCHEMA IF NOT EXISTS transient;

CREATE TABLE IF NOT EXISTS transient.raw (
    contest_number INTEGER PRIMARY KEY,
    payload JSONB NOT NULL,
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE transient.raw IS
    'One row per Lotofacil contest, holding the untouched JSON payload fetched from the Caixa public API.';
COMMENT ON COLUMN transient.raw.contest_number IS 'Lotofacil contest number (primary key).';
COMMENT ON COLUMN transient.raw.payload IS 'Raw JSON response from the API.';
COMMENT ON COLUMN transient.raw.fetched_at IS 'Timestamp when the row was loaded into PostgreSQL.';
