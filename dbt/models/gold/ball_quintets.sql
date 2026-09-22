-- Gold cube: one row per possible 5-ball combination (C(25,5) = 53,130 of
-- them), how many contests drew all 5 of them together.
-- - Why 5 and not 2 (a "pair matrix")? Two 15-of-25 draws always share at
--   least 15 + 15 - 25 = 5 balls (inclusion-exclusion) -- that floor is a
--   mathematical property of the game, not a coincidence of the data. A
--   pair's co-occurrence rate is close to uniform across all 300 pairs
--   (~35% per contest, hypergeometric) and mostly noise; a specific
--   quintet's rate (~5.65% per contest) sits right at that structural
--   floor, so it is the more meaningful unit to look at.
-- - together_qtty can be 0: every one of the 53,130 combinations is
--   included, not just the ones observed, the same "complete grain"
--   guarantee ball_frequency/ball_gap give their 25 rows. Expected count is
--   ~214 (3,785 contests * ~5.65%), so a 0 or a count far from that is the
--   interesting case.
-- - Built with two one-time combinatorics CTEs (no native "combinations"
--   function in Postgres): `universe`, every 5-ball combination out of the
--   25 balls (the row set), and `position_combos`, every 5-position
--   combination out of the 15 draw slots (computed once, not per contest,
--   then used to pick 5 balls out of each contest's sorted 15 -- the
--   positions don't depend on which contest, only the values at them do).
-- Built directly from silver (fact_ball_draws), not from cube_contest or
-- the other gold tables, matching the rule that gold tables are
-- independent of each other.
-- The primary key is (ball_1_nbr .. ball_5_nbr); left unnamed for the same
-- reason noted in dim_location.sql.
{{ config(
    tags=["quintet"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (ball_1_nbr, ball_2_nbr, ball_3_nbr, ball_4_nbr, ball_5_nbr)"
]) }}
with recursive fact_ball_draws as (
    select
        dim_contest_id,
        dim_ball_id
    from {{ ref('fact_ball_draws') }}
),

dim_ball as (
    select
        dim_ball_id,
        ball_nbr
    from {{ ref('dim_ball') }}
),

dim_contest as (
    select dim_contest_id
    from {{ ref('dim_contest') }}
),

-- Every 5-ball combination out of the 25 balls: C(25,5) = 53,130.
universe(quintet, last_ball) as (
    select array[b], b
    from generate_series(1, 25) as b
    union all
    select universe.quintet || b, b
    from universe, generate_series(universe.last_ball + 1, 25) as b
    where array_length(universe.quintet, 1) < 5
),

universe_5 as (
    select quintet
    from universe
    where array_length(quintet, 1) = 5
),

-- Every 5-position combination out of the 15 draw slots: C(15,5) = 3,003.
-- Computed once, independent of any contest.
position_combos(positions, last_position) as (
    select array[p], p
    from generate_series(1, 15) as p
    union all
    select position_combos.positions || p, p
    from position_combos, generate_series(position_combos.last_position + 1, 15) as p
    where array_length(position_combos.positions, 1) < 5
),

position_combos_5 as (
    select positions
    from position_combos
    where array_length(positions, 1) = 5
),

contest_balls as (
    select
        fbd.dim_contest_id,
        array_agg(db.ball_nbr order by db.ball_nbr) as balls_sorted
    from fact_ball_draws fbd
    inner join dim_ball db on db.dim_ball_id = fbd.dim_ball_id
    group by fbd.dim_contest_id
),

observed as (
    select
        array[
            cb.balls_sorted[pc.positions[1]],
            cb.balls_sorted[pc.positions[2]],
            cb.balls_sorted[pc.positions[3]],
            cb.balls_sorted[pc.positions[4]],
            cb.balls_sorted[pc.positions[5]]
        ] as quintet,
        count(*) as together_qtty
    from contest_balls cb
    cross join position_combos_5 pc
    group by 1
),

contest_count as (
    select count(*) as total_contest_qtty
    from dim_contest
)

select
    u.quintet[1] as ball_1_nbr,
    u.quintet[2] as ball_2_nbr,
    u.quintet[3] as ball_3_nbr,
    u.quintet[4] as ball_4_nbr,
    u.quintet[5] as ball_5_nbr,
    coalesce(o.together_qtty, 0) as together_qtty,
    round(100.0 * coalesce(o.together_qtty, 0) / cc.total_contest_qtty, 4) as together_pct
from universe_5 u
left join observed o on o.quintet = u.quintet
cross join contest_count cc
