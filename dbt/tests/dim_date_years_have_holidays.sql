-- Fails when dim_date has a year the holidays seed doesn't cover, which would
-- silently make every day of that year a non-holiday. dim_date grows with the
-- data (up to the latest next_draw_date), so run `uv run lotofacil holidays`
-- to extend the seed when this shows up. Returns the uncovered years.
select distinct year_nbr
from {{ ref('dim_date') }}
where year_nbr not in (
    select extract(year from holiday_date)::integer from {{ ref('holidays') }}
)
