-- Silver fact: one row per (contest, draw position). Factless fact — it
-- just records which ball was drawn where, no numeric measure to carry.
-- Column order mirrors bronze.ball_draws. Joining to every dimension it
-- references guarantees referential integrity and build order.
{{ config(
    tags=["fact"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} drop constraint if exists fk_fact_ball_draws_dim_contest",
    "alter table {{ this }} drop constraint if exists fk_fact_ball_draws_dim_draw_position",
    "alter table {{ this }} drop constraint if exists fk_fact_ball_draws_dim_ball",
    "alter table {{ this }} add primary key (contest_number, draw_order)",
    "alter table {{ this }} add constraint fk_fact_ball_draws_dim_contest foreign key (contest_number) references {{ ref('dim_contest') }} (contest_number)",
    "alter table {{ this }} add constraint fk_fact_ball_draws_dim_draw_position foreign key (draw_order) references {{ ref('dim_draw_position') }} (draw_order)",
    "alter table {{ this }} add constraint fk_fact_ball_draws_dim_ball foreign key (ball_number) references {{ ref('dim_ball') }} (ball_number)"
]) }}
select
    bd.contest_number,
    bd.draw_order,
    bd.ball_number
from {{ ref('ball_draws') }} bd
inner join {{ ref('dim_contest') }} c on c.contest_number = bd.contest_number
inner join {{ ref('dim_draw_position') }} p on p.draw_order = bd.draw_order
inner join {{ ref('dim_ball') }} b on b.ball_number = bd.ball_number
