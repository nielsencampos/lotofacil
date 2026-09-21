-- Silver dimension: the 5 prize tiers. Extracted out of bronze.prize_tiers
-- because the tier -> description mapping is constant across every
-- contest (faixa 1 is always "15 acertos", etc.) — storing it once here
-- instead of repeating it on every fact row is the actual point of
-- "snowflaking" a dimension out, as opposed to just splitting things up
-- for its own sake.
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (prize_tier)"
]) }}
select distinct
    prize_tier,
    prize_tier_description
from {{ ref('prize_tiers') }}
