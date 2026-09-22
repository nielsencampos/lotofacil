-- Gold cube: one row per ball (1-25), how long it has been since it last
-- came out, and how that compares with its own history.
-- - current_gap_qtty is how many contests have happened since the ball's
--   last appearance, as of the most recent contest: 0 if it came out in the
--   last contest, 1 if its last appearance was the contest before that, etc.
-- - max_gap_qtty is the longest gap this ball has ever had between two
--   consecutive appearances; avg_gap_avg is the average of all such gaps.
--   Both ignore the still-open current gap -- so a ball can be mid-record
--   (current_gap_qtty > max_gap_qtty) without max_gap_qtty itself moving
--   until that gap actually closes.
-- Built directly from silver (fact_ball_draws), not from cube_contest or
-- ball_frequency, matching the rule that gold tables are independent of
-- each other.
-- The primary key is ball_nbr; left unnamed for the same reason noted in
-- dim_location.sql.
{{ config(
    tags=["gap"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (ball_nbr)"
]) }}
with fact_ball_draws as (
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
    select
        dim_contest_id,
        contest_nbr,
        draw_dim_date_id
    from {{ ref('dim_contest') }}
),

dim_date as (
    select
        dim_date_id,
        date_dt
    from {{ ref('dim_date') }}
),

contests as (
    select
        c.dim_contest_id,
        c.contest_nbr,
        d.date_dt,
        row_number() over (order by c.contest_nbr) as contest_seq,
        row_number() over (order by c.contest_nbr desc) as recency_rank
    from dim_contest c
    inner join dim_date d on d.dim_date_id = c.draw_dim_date_id
),

-- Every contest each ball appeared in, chronologically, with the number of
-- contests it sat out since its previous appearance (null for the first).
appearances as (
    select
        fbd.dim_ball_id,
        c.contest_nbr,
        c.date_dt,
        c.contest_seq,
        c.recency_rank,
        c.contest_seq - lag(c.contest_seq) over (
            partition by fbd.dim_ball_id order by c.contest_seq
        ) - 1 as gap_qtty
    from fact_ball_draws fbd
    inner join contests c on c.dim_contest_id = fbd.dim_contest_id
),

last_appearance as (
    select distinct on (dim_ball_id)
        dim_ball_id,
        contest_nbr as last_contest_nbr,
        date_dt as last_draw_dt,
        recency_rank - 1 as current_gap_qtty
    from appearances
    order by dim_ball_id, recency_rank
),

gap_stats as (
    select
        dim_ball_id,
        max(gap_qtty) as max_gap_qtty,
        round(avg(gap_qtty), 2) as avg_gap_avg
    from appearances
    group by dim_ball_id
)

select
    b.ball_nbr,
    la.last_contest_nbr,
    la.last_draw_dt,
    la.current_gap_qtty,
    gs.max_gap_qtty,
    gs.avg_gap_avg
from dim_ball b
left join last_appearance la on la.dim_ball_id = b.dim_ball_id
left join gap_stats gs on gs.dim_ball_id = b.dim_ball_id
