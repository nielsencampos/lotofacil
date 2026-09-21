-- Silver dimension: one row per contest, descriptive attributes only.
-- Column order mirrors bronze.draws. The numeric measures that share this
-- same grain (collected_amount, accumulated amounts, etc.) live in
-- fact_contest_summary instead — Kimball convention: dimensions describe,
-- facts measure.
-- draw_city_state is split into draw_state/draw_city (normalized to
-- upper/trim) and FK'd to dim_municipality, unifying draw locations with
-- winning-ticket municipalities in one shared geography dimension.
-- draw_location (the venue, e.g. "ESPACO DA SORTE") is a different concept
-- — kept as free text, normalized to upper/trim, though that only
-- collapses pure-case duplicates; genuine typos (e.g. "ESPCAO" vs
-- "ESPACO") still create separate values and would need an explicit
-- mapping to fully dedupe.
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} drop constraint if exists fk_dim_contest_dim_municipality",
    "alter table {{ this }} add primary key (contest_number)",
    "alter table {{ this }} add constraint fk_dim_contest_dim_municipality foreign key (draw_state, draw_city) references {{ ref('dim_municipality') }} (state, city)"
]) }}
select
    d.contest_number,
    d.is_accumulated,
    d.draw_date,
    d.next_draw_date,
    d.show_city_detail,
    d.special_contest_indicator,
    upper(trim(d.draw_location)) as draw_location,
    upper(trim(split_part(d.draw_city_state, ',', 2))) as draw_state,
    upper(trim(split_part(d.draw_city_state, ',', 1))) as draw_city,
    trim(d.heart_team_name) as heart_team_name,
    d.previous_contest_number,
    d.final_contest_number_0_5,
    d.next_contest_number,
    d.game_number,
    trim(d.remarks) as remarks,
    upper(trim(d.game_type)) as game_type,
    d.publication_type,
    d.is_last_contest
from {{ ref('draws') }} d
inner join {{ ref('dim_municipality') }} m
    on m.state = upper(trim(split_part(d.draw_city_state, ',', 2)))
   and m.city = upper(trim(split_part(d.draw_city_state, ',', 1)))
