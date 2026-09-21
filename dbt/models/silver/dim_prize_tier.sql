-- Silver dimension: the 5 prize tiers. Extracted out of bronze.prize_tiers
-- because the tier -> description mapping is constant across every
-- contest (15 hits is always "15 acertos", etc.) — storing it once here
-- instead of repeating it on every fact row is the actual point of
-- "snowflaking" a dimension out, as opposed to just splitting things up
-- for its own sake.
-- The tier is identified by the number of hits (15, 14, ..., 11), which is
-- also dim_prize_tier_id, following the rule that an id equals the natural
-- number when there is one.
-- The description is normalized (upper case, unaccented) like the rest of the
-- text in silver: bronze keeps it as the source sent it ("15 acertos").
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (dim_prize_tier_id)",
    "alter table {{ this }} add unique (prize_tier_nbr)"
]) }}
select distinct
    prize_tier_number as dim_prize_tier_id,
    prize_tier_number as prize_tier_nbr,
    {{ normalize_text('prize_tier_description') }} as prize_tier_desc
from {{ ref('prize_tiers') }}
