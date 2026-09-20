-- Bronze layer: one row per (contest, draw position), straight from
-- dezenasSorteadasOrdemSorteio. Typed so it joins cleanly to the ball_names
-- and ball_orders dictionaries.
{{ config(post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (contest_number, draw_order)"
]) }}
select
    contest_number,
    ball_draw.ordinality::integer as draw_order,
    ball_draw.value::integer as ball_number
from {{ source('transient', 'raw') }},
    lateral jsonb_array_elements_text(payload -> 'dezenasSorteadasOrdemSorteio')
        with ordinality as ball_draw(value, ordinality)
