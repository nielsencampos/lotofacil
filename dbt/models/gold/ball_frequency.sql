-- Gold cube: one row per ball (1-25), its share of the balls drawn, over a
-- set of windows anchored on the most recent contest. Each window's 25
-- percentages are of that window's total picks (15 per contest, not the
-- contest count), so they always add up to 100 -- enforced by
-- tests/ball_frequency_pct_columns_sum_to_100.sql.
-- - Every contest window is cumulative: last_2_contests_pct is the last 2
--   contests taken together (not the second-to-last contest alone), same
--   for last_3_contests_pct, matching last_5/10/15/25_contests_pct. Windows
--   are by contest_nbr (the natural draw order), not by calendar time.
-- - last_contest_pct is the degenerate 1-contest case: 0 for the 10 balls
--   that didn't come out, 100/15 = 6.6667 for the 15 that did.
-- - last_1/2/3/5/10_years_pct are calendar windows instead: contests drawn
--   on or after (most recent draw date - N years), so unlike the
--   contest-count windows their denominator (how many contests fall in the
--   window) is itself computed, not a constant.
-- - total_pct is the whole history.
-- - Rounded to 4 decimals (not the usual 2) so the per-row rounding error
--   is small enough that every window's 25 percentages still sum to ~100.
-- Built directly from silver (fact_ball_draws), not from cube_contest,
-- matching the rule that gold tables are independent of each other.
-- The primary key is ball_nbr; left unnamed for the same reason noted in
-- dim_location.sql.
{{ config(
    tags=["frequency"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (ball_nbr)"
]) }}
{%- set contest_windows = [1, 2, 3, 5, 10, 15, 25] %}
{%- set year_windows = [1, 2, 3, 5, 10] %}
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
        d.date_dt,
        row_number() over (order by c.contest_nbr desc) as recency_rank
    from dim_contest c
    inner join dim_date d on d.dim_date_id = c.draw_dim_date_id
),

last_draw as (
    select max(date_dt) as last_draw_dt
    from contests
),

-- How many contests fall in each window (the percentages' denominator,
-- after multiplying by 15 picks per contest).
windows as (
    select
        count(*) as total_contest_qtty
        {%- for n in contest_windows %},
        count(*) filter (where c.recency_rank <= {{ n }}) as last_{{ n }}_contest_qtty
        {%- endfor %}
        {%- for y in year_windows %},
        count(*) filter (
            where c.date_dt >= ld.last_draw_dt - interval '{{ y }} year{{ 's' if y > 1 else '' }}'
        ) as last_{{ y }}_year_contest_qtty
        {%- endfor %}
    from contests c
    cross join last_draw ld
),

-- How many times each ball was drawn within each window (the percentages'
-- numerator).
ball_counts as (
    select
        fbd.dim_ball_id
        {%- for n in contest_windows %},
        count(*) filter (where c.recency_rank <= {{ n }}) as last_{{ n }}_contest_hit_qtty
        {%- endfor %}
        {%- for y in year_windows %},
        count(*) filter (
            where c.date_dt >= ld.last_draw_dt - interval '{{ y }} year{{ 's' if y > 1 else '' }}'
        ) as last_{{ y }}_year_hit_qtty
        {%- endfor %},
        count(*) as total_hit_qtty
    from fact_ball_draws fbd
    inner join contests c on c.dim_contest_id = fbd.dim_contest_id
    cross join last_draw ld
    group by fbd.dim_ball_id
)

select
    b.ball_nbr
    {%- for n in contest_windows %},
    round(100.0 * coalesce(bc.last_{{ n }}_contest_hit_qtty, 0) / (15 * w.last_{{ n }}_contest_qtty), 4)
        as {{ 'last_contest_pct' if n == 1 else 'last_' ~ n ~ '_contests_pct' }}
    {%- endfor %}
    {%- for y in year_windows %},
    round(100.0 * coalesce(bc.last_{{ y }}_year_hit_qtty, 0) / (15 * w.last_{{ y }}_year_contest_qtty), 4)
        as last_{{ y }}_year{{ 's' if y > 1 else '' }}_pct
    {%- endfor %},
    round(100.0 * coalesce(bc.total_hit_qtty, 0) / (15 * w.total_contest_qtty), 4) as total_pct
-- left join, not inner: a ball absent from fact_ball_draws (never drawn in
-- the loaded history) must still get a row here, at 0% everywhere, to match
-- the documented "one row per ball (1-25)" grain.
from dim_ball b
left join ball_counts bc on bc.dim_ball_id = b.dim_ball_id
cross join windows w
