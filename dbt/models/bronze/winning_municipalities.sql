-- Bronze layer: one row per (contest, winning municipality), straight from
-- listaMunicipioUFGanhadores, with proper types and English column names.
-- Most contests have no winners at the top prize tier, so this table has
-- far fewer rows than there are contests. `serie` and `nomeFatansiaUL` are
-- dropped since they are always an empty string (verified across all rows).
-- `winner_index` is the entry's position in the source array: the source
-- `posicao` field is always 1, so it can't be part of a unique key.
{{ config(post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (contest_number, winner_index)"
]) }}
select
    contest_number,
    winner.ordinality::integer as winner_index,
    winner.value ->> 'uf' as state,
    winner.value ->> 'municipio' as city,
    (winner.value ->> 'posicao')::integer as winner_position,
    (winner.value ->> 'ganhadores')::integer as winner_count
from {{ source('transient', 'raw') }},
    lateral jsonb_array_elements(payload -> 'listaMunicipioUFGanhadores')
        with ordinality as winner(value, ordinality)
