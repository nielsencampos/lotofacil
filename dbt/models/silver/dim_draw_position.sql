-- Silver dimension: one row per draw position (1-15), from the ball_orders
-- dictionary (bronze draw_order -> draw_position_nbr, name ->
-- draw_position_nm, so it's unambiguous next to dim_ball's name).
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (dim_draw_position_id)",
    "alter table {{ this }} add unique (draw_position_nbr)"
]) }}
with ball_orders as (
    select
        draw_order,
        name
    from {{ ref('ball_orders') }}
)

select
    draw_order as dim_draw_position_id,
    draw_order as draw_position_nbr,
    name as draw_position_nm
from ball_orders
