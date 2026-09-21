-- Silver dimension: distinct (state, city) pairs observed both among
-- winning tickets (bronze.winning_municipalities) and draw locations
-- (bronze.draws.draw_city_state) — one shared geography dimension for both
-- use cases. Values are normalized to upper/trim so entries that only
-- differ by case collapse together (e.g. "Irece" and "IRECE" were
-- previously two separate rows). Not a complete list of all Brazilian
-- states/cities. Some placeholder/garbage state codes ("--", "XX", "C",
-- "G") remain from winning tickets with no physical municipality on
-- record — kept as-is here for fidelity; decide how to bucket/exclude
-- them, if at all, in a downstream gold model.
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (state, city)"
]) }}
with from_winners as (
    select
        upper(trim(state)) as state,
        upper(trim(city)) as city
    from {{ ref('winning_municipalities') }}
),

from_draws as (
    select
        upper(trim(split_part(draw_city_state, ',', 2))) as state,
        upper(trim(split_part(draw_city_state, ',', 1))) as city
    from {{ ref('draws') }}
)

select state, city from from_winners
union
select state, city from from_draws
