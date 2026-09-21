-- Silver fact: one row per contest — the numeric measures split out of
-- dim_contest, in the same order as bronze.draws.
-- - fact_contest_summary_id is a deterministic numeric md5 of the grain (see
--   dbt/macros/numeric_md5.sql); the grain itself, dim_contest_id, is
--   enforced as UNIQUE. Decimal values are _amt (thesaurus).
-- - accumulated_amt is the bronze accumulated_amount_0_5 (the "0-5" cycle);
--   the 0_5 is dropped from the name like it is in dim_contest.
-- Joining to dim_contest guarantees referential integrity and tells dbt to
-- build dim_contest first. Constraints are left unnamed where they create an
-- index — see the note in dim_location.sql on why.
{{ config(
    tags=["fact"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} drop constraint if exists fk_fact_contest_summary_dim_contest",
    "alter table {{ this }} add primary key (fact_contest_summary_id)",
    "alter table {{ this }} add unique (dim_contest_id)",
    "alter table {{ this }} add constraint fk_fact_contest_summary_dim_contest foreign key (dim_contest_id) references {{ ref('dim_contest') }} (dim_contest_id)"
]) }}
select
    {{ numeric_md5(['c.dim_contest_id']) }} as fact_contest_summary_id,
    c.dim_contest_id,
    d.collected_amount as collected_amt,
    d.accumulated_amount_0_5 as accumulated_amt,
    d.special_accumulated_amount as special_accumulated_amt,
    d.next_accumulated_amount as next_accumulated_amt,
    d.next_estimated_prize as next_estimated_prize_amt,
    d.guarantee_fund_balance as guarantee_fund_balance_amt,
    d.total_prize_tier_one_amount as total_prize_tier_one_amt
from {{ ref('draws') }} d
inner join {{ ref('dim_contest') }} c on c.contest_nbr = d.contest_number
