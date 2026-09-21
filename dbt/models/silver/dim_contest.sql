-- Silver dimension: one row per contest, descriptive attributes only. The
-- numeric measures that share this same grain (collected_amt, accumulated
-- amounts, etc.) live in fact_contest_summary instead — Kimball convention:
-- dimensions describe, facts measure.
-- - Where the draw happened (draw_location + draw_city_state in bronze) is
--   now just dim_location_id, an FK to dim_location. The lookup runs the same
--   normalize_* macros dim_location was built with, so it always matches.
-- - Dates are dim_date ids, not raw dates: draw_dim_date_id (the draw day) and
--   next_draw_dim_date_id (the next scheduled draw) are two roles of the same
--   dimension. The next one uses a left join so a missing date could never
--   make a contest disappear.
-- - independence_day_flg: this was a Lotofacil da Independencia draw. The API
--   marks it (special_contest_indicator = 2) for only 9 of the 14 draws, so
--   the flag also uses the signature all 14 share: from 2013 on, in
--   September, the special accumulated amount is 0 (it resets on that draw;
--   it is 0 on exactly one contest per year, whereas before 2013 it was 0 on
--   every contest because the column didn't exist yet). The API does not
--   mark 2013-2016 and 2019. tests/independence_day_at_most_one_per_year.sql
--   guards the rule against over-flagging.
-- - Bronze columns that carry no information were dropped in bronze itself
--   (game type/number, publication type, heart team and is_last_contest have
--   the same value on every contest).
-- Constraints are left unnamed where they create an index — see the note in
-- dim_location.sql on why.
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} drop constraint if exists fk_dim_contest_dim_location",
    "alter table {{ this }} drop constraint if exists fk_dim_contest_dim_date_draw",
    "alter table {{ this }} drop constraint if exists fk_dim_contest_dim_date_next_draw",
    "alter table {{ this }} add primary key (dim_contest_id)",
    "alter table {{ this }} add unique (contest_nbr)",
    "alter table {{ this }} add constraint fk_dim_contest_dim_location foreign key (dim_location_id) references {{ ref('dim_location') }} (dim_location_id)",
    "alter table {{ this }} add constraint fk_dim_contest_dim_date_draw foreign key (draw_dim_date_id) references {{ ref('dim_date') }} (dim_date_id)",
    "alter table {{ this }} add constraint fk_dim_contest_dim_date_next_draw foreign key (next_draw_dim_date_id) references {{ ref('dim_date') }} (dim_date_id)"
]) }}
select
    d.contest_number as dim_contest_id,
    d.contest_number as contest_nbr,
    l.dim_location_id,
    dd_draw.dim_date_id as draw_dim_date_id,
    dd_next.dim_date_id as next_draw_dim_date_id,
    d.is_accumulated as is_accumulated_flg,
    d.show_city_detail as show_city_detail_flg,
    coalesce(
        d.special_contest_indicator = 2
        or (
            d.draw_date >= date '2013-01-01'
            and extract(month from d.draw_date) = 9
            and d.special_accumulated_amount = 0
        ),
        false
    ) as independence_day_flg,
    {{ normalize_text('d.remarks') }} as remarks_desc,
    d.previous_contest_number as previous_contest_nbr,
    d.final_contest_number_0_5 as final_contest_nbr,
    d.next_contest_number as next_contest_nbr
from {{ ref('draws') }} d
inner join {{ ref('dim_location') }} l
    on l.location_nm = {{ normalize_location_nm('d.draw_location') }}
   and l.city_nm = {{ normalize_city_nm("split_part(d.draw_city_state, ',', 1)") }}
   and l.state_cd = {{ normalize_state_cd("split_part(d.draw_city_state, ',', 2)", "split_part(d.draw_city_state, ',', 1)") }}
inner join {{ ref('dim_date') }} dd_draw on dd_draw.date_dt = d.draw_date
left join {{ ref('dim_date') }} dd_next on dd_next.date_dt = d.next_draw_date
