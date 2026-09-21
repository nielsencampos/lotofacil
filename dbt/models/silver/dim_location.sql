-- Silver dimension: one row per distinct (location, city, state) seen either
-- among winning tickets (bronze.winning_municipalities) or draws
-- (bronze.draws) — a single shared geography dimension for both.
-- - Winning tickets only know state/city, so their location_nm is
--   '---NAO INFORMADO---'; draws also carry the venue (draw_location).
-- - Everything goes through the normalize_* macros (upper/trim/unaccent,
--   blanks -> '---NAO INFORMADO---', canal eletronico -> 'XX', "C"/"G" ->
--   "CE"/"GO"), see dbt/macros/normalize_texts.sql. dim_contest and
--   fact_winning_municipalities run the same macros so their joins here
--   keep matching.
-- - Draw venues are also mapped to a canonical name (typos and word-order
--   variants, e.g. "ESPCAO LOTERIAS CAIXA" -> "ESPACO LOTERIAS CAIXA"); only
--   6 location_nm values are expected, enforced by an accepted_values test.
-- - dim_location_id is a deterministic numeric md5 of the natural key (see
--   dbt/macros/numeric_md5.sql), so it doesn't shift between rebuilds the way
--   row_number() would. The natural key stays enforced as UNIQUE.
-- Not a complete list of Brazilian cities — only what has appeared so far.
-- Constraints are left unnamed on purpose: dbt rebuilds a table by building
-- the new one next to the old, and the post-hook runs before the old table
-- is dropped, so an explicitly-named index/constraint collides with the old
-- table's. Postgres auto-names (and de-duplicates) the unnamed ones.
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} add primary key (dim_location_id)",
    "alter table {{ this }} add unique (location_nm, city_nm, state_cd)"
]) }}
with from_winners as (
    select
        {{ not_informed() }} as location_nm,
        {{ normalize_city_nm('city') }} as city_nm,
        {{ normalize_state_cd('state', 'city') }} as state_cd
    from {{ ref('winning_municipalities') }}
),

from_draws as (
    select
        {{ normalize_location_nm('draw_location') }} as location_nm,
        {{ normalize_city_nm("split_part(draw_city_state, ',', 1)") }} as city_nm,
        {{ normalize_state_cd("split_part(draw_city_state, ',', 2)", "split_part(draw_city_state, ',', 1)") }} as state_cd
    from {{ ref('draws') }}
),

all_locations as (
    select location_nm, city_nm, state_cd from from_winners
    union
    select location_nm, city_nm, state_cd from from_draws
)

select
    {{ numeric_md5(['location_nm', 'city_nm', 'state_cd']) }} as dim_location_id,
    location_nm,
    city_nm,
    state_cd
from all_locations
