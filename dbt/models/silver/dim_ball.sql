-- Silver dimension: one row per ball number (1-25). Renamed from bronze's
-- generic number/name so it's unambiguous once joined into a fact table
-- alongside dim_draw_position (which also has a "name" column in bronze).
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (ball_number)"
]) }}
select
    number as ball_number,
    name as ball_name
from {{ ref('ball_names') }}
