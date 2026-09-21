-- The cube must hold exactly one row per contest of dim_contest. The inner
-- joins in cube_contest would silently drop a contest that lacked balls, prize
-- tiers or a summary row; this returns the contests that went missing.
select dim_contest_id
from {{ ref('dim_contest') }}
where contest_nbr not in (select contest_nbr from {{ ref('cube_contest') }})
