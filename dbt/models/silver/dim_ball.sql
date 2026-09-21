-- Silver dimension: one row per ball number (1-25), from the ball_names
-- dictionary (bronze number -> ball_nbr, name -> ball_nm, so it's
-- unambiguous next to dim_draw_position's name).
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (dim_ball_id)",
    "alter table {{ this }} add unique (ball_nbr)"
]) }}
select
    number as dim_ball_id,
    number as ball_nbr,
    name as ball_nm
from {{ ref('ball_names') }}
