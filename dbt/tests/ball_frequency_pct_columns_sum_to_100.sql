-- Every _pct column in ball_frequency is a share of that window's total ball
-- picks across the 25 balls, so each column must sum to 100 (a small
-- tolerance absorbs the per-row rounding to 4 decimals). Returns the columns
-- that don't -- including a NULL sum (ball_frequency built with 0 rows),
-- which `sum() over nothing` would otherwise let slip past `> 0.01`.
select column_nm, total_pct
from (
    select 'last_contest_pct' as column_nm, sum(last_contest_pct) as total_pct from {{ ref('ball_frequency') }}
    union all
    select 'last_2_contests_pct', sum(last_2_contests_pct) from {{ ref('ball_frequency') }}
    union all
    select 'last_3_contests_pct', sum(last_3_contests_pct) from {{ ref('ball_frequency') }}
    union all
    select 'last_5_contests_pct', sum(last_5_contests_pct) from {{ ref('ball_frequency') }}
    union all
    select 'last_10_contests_pct', sum(last_10_contests_pct) from {{ ref('ball_frequency') }}
    union all
    select 'last_15_contests_pct', sum(last_15_contests_pct) from {{ ref('ball_frequency') }}
    union all
    select 'last_25_contests_pct', sum(last_25_contests_pct) from {{ ref('ball_frequency') }}
    union all
    select 'last_1_year_pct', sum(last_1_year_pct) from {{ ref('ball_frequency') }}
    union all
    select 'last_2_years_pct', sum(last_2_years_pct) from {{ ref('ball_frequency') }}
    union all
    select 'last_3_years_pct', sum(last_3_years_pct) from {{ ref('ball_frequency') }}
    union all
    select 'last_5_years_pct', sum(last_5_years_pct) from {{ ref('ball_frequency') }}
    union all
    select 'last_10_years_pct', sum(last_10_years_pct) from {{ ref('ball_frequency') }}
    union all
    select 'total_pct', sum(total_pct) from {{ ref('ball_frequency') }}
) sums
where total_pct is null or abs(total_pct - 100) > 0.01
