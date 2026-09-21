-- Silver dimension: one row per draw position (1-15). Renamed from bronze's
-- generic name for the same reason as dim_ball.
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (draw_order)"
]) }}
select
    draw_order,
    name as draw_position_name
from {{ ref('ball_orders') }}
