-- Silver fact: one row per contest — the numeric measures split out of
-- dim_contest. Column order mirrors bronze.draws.
-- Joining to dim_contest (even though it adds no extra column) guarantees
-- referential integrity and tells dbt to build dim_contest first.
{{ config(
    tags=["fact"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} drop constraint if exists fk_fact_contest_summary_dim_contest",
    "alter table {{ this }} add primary key (contest_number)",
    "alter table {{ this }} add constraint fk_fact_contest_summary_dim_contest foreign key (contest_number) references {{ ref('dim_contest') }} (contest_number)"
]) }}
select
    d.contest_number,
    d.collected_amount,
    d.accumulated_amount_0_5,
    d.special_accumulated_amount,
    d.next_accumulated_amount,
    d.next_estimated_prize,
    d.guarantee_fund_balance,
    d.total_prize_tier_one_amount
from {{ ref('draws') }} d
inner join {{ ref('dim_contest') }} c on c.contest_number = d.contest_number
