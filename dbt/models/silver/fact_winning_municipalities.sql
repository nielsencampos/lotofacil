-- Silver fact: one row per (contest, winning municipality). Column order
-- mirrors bronze.winning_municipalities. winner_position stays here as a
-- degenerate attribute (it's always 1 in the data seen so far, not worth
-- its own dimension). state/city are normalized (upper/trim) to match
-- dim_municipality — the raw bronze values sometimes differ only by case
-- (e.g. "Irece" vs "IRECE"), which would otherwise fail to join here.
{{ config(
    tags=["fact"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} drop constraint if exists fk_fact_winning_municipalities_dim_contest",
    "alter table {{ this }} drop constraint if exists fk_fact_winning_municipalities_dim_municipality",
    "alter table {{ this }} add primary key (contest_number, winner_index)",
    "alter table {{ this }} add constraint fk_fact_winning_municipalities_dim_contest foreign key (contest_number) references {{ ref('dim_contest') }} (contest_number)",
    "alter table {{ this }} add constraint fk_fact_winning_municipalities_dim_municipality foreign key (state, city) references {{ ref('dim_municipality') }} (state, city)"
]) }}
select
    wm.contest_number,
    wm.winner_index,
    upper(trim(wm.state)) as state,
    upper(trim(wm.city)) as city,
    wm.winner_position,
    wm.winner_count
from {{ ref('winning_municipalities') }} wm
inner join {{ ref('dim_contest') }} c on c.contest_number = wm.contest_number
inner join {{ ref('dim_municipality') }} m
    on m.state = upper(trim(wm.state))
   and m.city = upper(trim(wm.city))
