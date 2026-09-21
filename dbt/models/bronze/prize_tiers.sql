-- Bronze layer: one row per (contest, prize tier), straight from
-- listaRateioPremio, with proper types and English column names.
-- prize_tier_number is the number of hits that wins the tier (15, 14, ..., 11),
-- read from the text of descricaoFaixa ("15 acertos") instead of using the
-- source's ordinal `faixa` (1..5), which maps 1:1 to it (1 = 15 hits ... 5 =
-- 11 hits, checked across all 18,920 rows) and so is not kept.
{{ config(post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (contest_number, prize_tier_number)"
]) }}
select
    contest_number,
    substring(tier ->> 'descricaoFaixa' from '[0-9]+')::integer as prize_tier_number,
    tier ->> 'descricaoFaixa' as prize_tier_description,
    (tier ->> 'numeroDeGanhadores')::integer as winner_count,
    (tier ->> 'valorPremio')::numeric as prize_amount
from {{ source('transient', 'raw') }},
    lateral jsonb_array_elements(payload -> 'listaRateioPremio') as tier
