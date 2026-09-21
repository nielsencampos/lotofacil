-- Silver fact: one row per (contest, prize tier). Column order mirrors
-- bronze.prize_tiers, minus prize_tier_description — that now lives in
-- dim_prize_tier instead of being repeated on every row.
{{ config(
    tags=["fact"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} drop constraint if exists fk_fact_prize_tiers_dim_contest",
    "alter table {{ this }} drop constraint if exists fk_fact_prize_tiers_dim_prize_tier",
    "alter table {{ this }} add primary key (contest_number, prize_tier)",
    "alter table {{ this }} add constraint fk_fact_prize_tiers_dim_contest foreign key (contest_number) references {{ ref('dim_contest') }} (contest_number)",
    "alter table {{ this }} add constraint fk_fact_prize_tiers_dim_prize_tier foreign key (prize_tier) references {{ ref('dim_prize_tier') }} (prize_tier)"
]) }}
select
    pt.contest_number,
    pt.prize_tier,
    pt.winner_count,
    pt.prize_amount
from {{ ref('prize_tiers') }} pt
inner join {{ ref('dim_contest') }} c on c.contest_number = pt.contest_number
inner join {{ ref('dim_prize_tier') }} dpt on dpt.prize_tier = pt.prize_tier
