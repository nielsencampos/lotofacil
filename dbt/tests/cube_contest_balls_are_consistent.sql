-- Each contest draws 15 distinct balls, and balls_sorted must be exactly
-- balls_draw_order in ascending order. Returns the contests that break it.
select contest_nbr
from {{ ref('cube_contest') }}
where cardinality(balls_draw_order) <> 15
   or cardinality(balls_sorted) <> 15
   or (select count(distinct ball) from unnest(balls_draw_order) as ball) <> 15
   or balls_sorted <> (select array_agg(ball order by ball) from unnest(balls_draw_order) as ball)
