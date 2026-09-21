-- Silver fact: one row per (contest, prize tier). Column order mirrors
-- bronze.prize_tiers, minus prize_tier_description — that lives in
-- dim_prize_tier instead of being repeated on every row.
-- - fact_prize_tier_id is a deterministic numeric md5 of the grain (contest +
--   prize tier); the grain is enforced as UNIQUE. See
--   dbt/macros/numeric_md5.sql.
-- - Thesaurus: winner_qtty is an integer (_qtty), prize_amt a decimal (_amt).
-- Constraints are left unnamed where they create an index — see the note in
-- dim_location.sql on why.
{{ config(
    tags=["fact"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} drop constraint if exists fk_fact_prize_tiers_dim_contest",
    "alter table {{ this }} drop constraint if exists fk_fact_prize_tiers_dim_prize_tier",
    "alter table {{ this }} add primary key (fact_prize_tier_id)",
    "alter table {{ this }} add unique (dim_contest_id, dim_prize_tier_id)",
    "alter table {{ this }} add constraint fk_fact_prize_tiers_dim_contest foreign key (dim_contest_id) references {{ ref('dim_contest') }} (dim_contest_id)",
    "alter table {{ this }} add constraint fk_fact_prize_tiers_dim_prize_tier foreign key (dim_prize_tier_id) references {{ ref('dim_prize_tier') }} (dim_prize_tier_id)"
]) }}
select
    {{ numeric_md5(['c.dim_contest_id', 'dpt.dim_prize_tier_id']) }} as fact_prize_tier_id,
    c.dim_contest_id,
    dpt.dim_prize_tier_id,
    pt.winner_count as winner_qtty,
    pt.prize_amount as prize_amt
from {{ ref('prize_tiers') }} pt
inner join {{ ref('dim_contest') }} c on c.contest_nbr = pt.contest_number
inner join {{ ref('dim_prize_tier') }} dpt on dpt.prize_tier_nbr = pt.prize_tier
