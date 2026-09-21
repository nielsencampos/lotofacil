-- Silver fact: one row per (contest, draw position). Factless fact — it
-- just records which ball was drawn where, no numeric measure to carry.
-- - fact_ball_draw_id is a deterministic numeric md5 of the grain (contest +
--   position, deliberately NOT the ball: the ball is an attribute, so a
--   corrected result must not change the row's id); the grain is enforced as
--   UNIQUE. See dbt/macros/numeric_md5.sql.
-- Joining to every dimension it references guarantees referential integrity
-- and build order. Constraints are left unnamed where they create an index —
-- see the note in dim_location.sql on why.
{{ config(
    tags=["fact"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} drop constraint if exists fk_fact_ball_draws_dim_contest",
    "alter table {{ this }} drop constraint if exists fk_fact_ball_draws_dim_draw_position",
    "alter table {{ this }} drop constraint if exists fk_fact_ball_draws_dim_ball",
    "alter table {{ this }} add primary key (fact_ball_draw_id)",
    "alter table {{ this }} add unique (dim_contest_id, dim_draw_position_id)",
    "alter table {{ this }} add constraint fk_fact_ball_draws_dim_contest foreign key (dim_contest_id) references {{ ref('dim_contest') }} (dim_contest_id)",
    "alter table {{ this }} add constraint fk_fact_ball_draws_dim_draw_position foreign key (dim_draw_position_id) references {{ ref('dim_draw_position') }} (dim_draw_position_id)",
    "alter table {{ this }} add constraint fk_fact_ball_draws_dim_ball foreign key (dim_ball_id) references {{ ref('dim_ball') }} (dim_ball_id)"
]) }}
select
    {{ numeric_md5(['c.dim_contest_id', 'p.dim_draw_position_id']) }} as fact_ball_draw_id,
    c.dim_contest_id,
    p.dim_draw_position_id,
    b.dim_ball_id
from {{ ref('ball_draws') }} bd
inner join {{ ref('dim_contest') }} c on c.contest_nbr = bd.contest_number
inner join {{ ref('dim_draw_position') }} p on p.draw_position_nbr = bd.draw_order
inner join {{ ref('dim_ball') }} b on b.ball_nbr = bd.ball_number
