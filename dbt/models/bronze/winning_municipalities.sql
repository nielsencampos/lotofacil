-- Bronze layer: one row per (contest, winning municipality), straight from
-- listaMunicipioUFGanhadores, with proper types and English column names.
-- Most contests have no winners at the top prize tier, so this table has
-- far fewer rows than there are contests. Dropped because they carry no
-- information (verified across all 10,546 rows): `serie` and
-- `nomeFatansiaUL` (always an empty string) and `posicao` (always 1).
-- `winner_index` is the entry's position in the source array; it is what
-- makes a row unique, since `posicao` can't tell rows apart.
{{ config(post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (contest_number, winner_index)"
]) }}
select
    contest_number,
    winner.ordinality::integer as winner_index,
    winner.value ->> 'uf' as state,
    winner.value ->> 'municipio' as city,
    (winner.value ->> 'ganhadores')::integer as winner_count
from {{ source('transient', 'raw') }},
    lateral jsonb_array_elements(payload -> 'listaMunicipioUFGanhadores')
        with ordinality as winner(value, ordinality)
