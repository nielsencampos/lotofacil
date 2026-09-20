-- Bronze layer: one row per (contest, prize tier), straight from
-- listaRateioPremio, with proper types and English column names.
{{ config(post_hook="alter table {{ this }} add primary key (contest_number, prize_tier)") }}
select
    contest_number,
    (tier ->> 'faixa')::integer as prize_tier,
    tier ->> 'descricaoFaixa' as prize_tier_description,
    (tier ->> 'numeroDeGanhadores')::integer as winner_count,
    (tier ->> 'valorPremio')::numeric as prize_amount
from {{ source('transient', 'raw') }},
    lateral jsonb_array_elements(payload -> 'listaRateioPremio') as tier
