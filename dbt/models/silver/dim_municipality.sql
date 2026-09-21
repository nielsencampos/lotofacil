-- Silver dimension: distinct (state, city) pairs observed both among
-- winning tickets (bronze.winning_municipalities) and draw locations
-- (bronze.draws.draw_city_state) — one shared geography dimension for both
-- use cases. Values are normalized to upper/trim/unaccent so entries that
-- only differ by case or accent collapse together (e.g. "Irece"/"IRECE"
-- and "MACEIO"/"MACEIÓ" were previously separate rows). Online/app ticket
-- sales are recorded under two inconsistent placeholders — (state='--',
-- city='CANAL ELETRONICO') and (state='XX', city='Canal Eletrônico') —
-- canonicalized here to state='XX' (the city side already collapses once
-- unaccented). Two truncated state codes are also fixed: "C" -> "CE"
-- (city is Fortaleza, Ceará's capital) and "G" -> "GO" (city is Santa
-- Helena de Goias). See dbt/macros/normalize_municipality.sql.
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (state, city)"
]) }}
with from_winners as (
    select
        {{ normalize_municipality_state('state', 'city') }} as state,
        {{ normalize_municipality_city('city') }} as city
    from {{ ref('winning_municipalities') }}
),

from_draws as (
    select
        {{ normalize_municipality_state("split_part(draw_city_state, ',', 2)", "split_part(draw_city_state, ',', 1)") }} as state,
        {{ normalize_municipality_city("split_part(draw_city_state, ',', 1)") }} as city
    from {{ ref('draws') }}
)

select state, city from from_winners
union
select state, city from from_draws
