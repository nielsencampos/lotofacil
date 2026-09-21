-- Silver fact: one row per (contest, winning municipality). Column order
-- mirrors bronze.winning_municipalities, with state/city replaced by
-- dim_location_id.
-- - The dim_location lookup runs the same normalize_* macros dim_location was
--   built with (winning tickets have no venue, so they match the
--   '---NAO SE APLICA---' location) — otherwise this wouldn't join.
-- - fact_winning_municipality_id is a deterministic numeric md5 of the grain
--   (contest + winner_index_nbr); the grain is enforced as UNIQUE. See
--   dbt/macros/numeric_md5.sql.
-- - winner_index_nbr is the entry's position in the source array;
--   winner_position_nbr stays as a degenerate attribute (it's always 1 in the
--   data seen so far, not worth its own dimension); winner_qtty is a count
--   (_qtty).
-- Constraints are left unnamed where they create an index — see the note in
-- dim_location.sql on why.
{{ config(
    tags=["fact"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} drop constraint if exists fk_fact_winning_municipalities_dim_contest",
    "alter table {{ this }} drop constraint if exists fk_fact_winning_municipalities_dim_location",
    "alter table {{ this }} add primary key (fact_winning_municipality_id)",
    "alter table {{ this }} add unique (dim_contest_id, winner_index_nbr)",
    "alter table {{ this }} add constraint fk_fact_winning_municipalities_dim_contest foreign key (dim_contest_id) references {{ ref('dim_contest') }} (dim_contest_id)",
    "alter table {{ this }} add constraint fk_fact_winning_municipalities_dim_location foreign key (dim_location_id) references {{ ref('dim_location') }} (dim_location_id)"
]) }}
select
    {{ numeric_md5(['c.dim_contest_id', 'wm.winner_index']) }} as fact_winning_municipality_id,
    c.dim_contest_id,
    wm.winner_index as winner_index_nbr,
    l.dim_location_id,
    wm.winner_position as winner_position_nbr,
    wm.winner_count as winner_qtty
from {{ ref('winning_municipalities') }} wm
inner join {{ ref('dim_contest') }} c on c.contest_nbr = wm.contest_number
inner join {{ ref('dim_location') }} l
    on l.location_nm = {{ not_applicable() }}
   and l.city_nm = {{ normalize_city_nm('wm.city') }}
   and l.state_cd = {{ normalize_state_cd('wm.state', 'wm.city') }}
