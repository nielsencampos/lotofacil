-- Every contest contributes exactly C(15,5) = 3,003 quintets (5-ball
-- subsets of its 15 drawn balls), so summing together_qtty across all
-- 53,130 possible combinations must equal total contests * 3,003 exactly
-- (integer counts, no rounding tolerance needed). Returns the two sides
-- when they don't match.
select
    sum(bq.together_qtty) as actual_total,
    (select count(*) from {{ ref('dim_contest') }}) * 3003 as expected_total
from {{ ref('ball_quintets') }} bq
having sum(bq.together_qtty) <> (select count(*) from {{ ref('dim_contest') }}) * 3003
