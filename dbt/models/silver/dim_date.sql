-- Silver dimension: one row per calendar day, so other tables can carry
-- dim_date_id instead of a raw date.
-- - Range: every single day (not only contest days), from the first contest's
--   date up to the latest next_draw_date, i.e. the next scheduled draw. That
--   covers every date dim_contest points at, so neither draw_dim_date_id nor
--   next_draw_dim_date_id can come out NULL. It depends only on the data (no
--   clock), so the model is deterministic and grows as new contests arrive.
-- - dim_date_id is the smart key yyyymmdd (e.g. 20260921): readable, sortable,
--   and unlike a hash it can be read straight off a fact row. date_dt stays
--   as the unique natural key.
-- - Names are Portuguese, upper case and unaccented, like the other text in
--   silver (MARCO, TERCA-FEIRA, SABADO). Weeks are ISO weeks (Monday first).
-- - Holidays come from the holidays seed (Brazilian national holidays as listed by
--   BrasilAPI, so Carnaval, Sexta-feira Santa, Pascoa and Corpus Christi count).
--   holiday_flg says whether the day is one; holiday_nm names it, or is
--   ---NAO SE APLICA--- on any other day. Only the years present in the seed are
--   covered, which the dim_date_years_have_holidays test enforces.
-- Constraints are left unnamed where they create an index — see the note in
-- dim_location.sql on why.
{{ config(
    tags=["dim"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (dim_date_id)",
    "alter table {{ this }} add unique (date_dt)"
]) }}
{%- set month_names = ['JANEIRO', 'FEVEREIRO', 'MARCO', 'ABRIL', 'MAIO', 'JUNHO', 'JULHO', 'AGOSTO', 'SETEMBRO', 'OUTUBRO', 'NOVEMBRO', 'DEZEMBRO'] -%}
{%- set month_abbrs = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'] -%}
{%- set weekday_names = ['SEGUNDA-FEIRA', 'TERCA-FEIRA', 'QUARTA-FEIRA', 'QUINTA-FEIRA', 'SEXTA-FEIRA', 'SABADO', 'DOMINGO'] -%}
{%- set weekday_abbrs = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB', 'DOM'] %}
with draws as (
    select
        draw_date,
        next_draw_date
    from {{ ref('draws') }}
),

holidays as (
    select
        holiday_date,
        holiday_name
    from {{ ref('holidays') }}
),

bounds as (
    select
        min(draw_date) as start_dt,
        greatest(max(draw_date), max(next_draw_date)) as end_dt
    from draws
),

calendar as (
    select generate_series(start_dt, end_dt, interval '1 day')::date as date_dt
    from bounds
),

parts as (
    select
        date_trunc('month', date_dt)::date as month_start_dt,
        date_dt,
        extract(year from date_dt)::integer as year_nbr,
        extract(month from date_dt)::integer as month_nbr,
        extract(day from date_dt)::integer as day_nbr,
        extract(isodow from date_dt)::integer as day_of_week_nbr,
        extract(isoyear from date_dt)::integer as iso_year_nbr,
        extract(week from date_dt)::integer as iso_week_nbr
    from calendar
),

enriched as (
    select
        *,
        (month_start_dt + interval '1 month' - interval '1 day')::date as month_end_dt,
        ceil(month_nbr / 2.0)::integer as bimester_nbr,
        ceil(month_nbr / 3.0)::integer as quarter_nbr,
        ceil(month_nbr / 6.0)::integer as semester_nbr
    from parts
)

select
    to_char(date_dt, 'YYYYMMDD')::integer as dim_date_id,
    date_dt,
    to_char(date_dt, 'DD/MM/YYYY') as date_desc,
    (array['{{ weekday_names | join("', '") }}'])[day_of_week_nbr]
        || ', ' || day_nbr || ' DE '
        || (array['{{ month_names | join("', '") }}'])[month_nbr]
        || ' DE ' || year_nbr as date_long_desc,

    year_nbr,
    ((year_nbr % 4 = 0 and year_nbr % 100 <> 0) or year_nbr % 400 = 0) as leap_year_flg,

    semester_nbr,
    semester_nbr || 'O SEMESTRE' as semester_nm,
    year_nbr * 10 + semester_nbr as year_semester_nbr,

    quarter_nbr,
    quarter_nbr || 'O TRIMESTRE' as quarter_nm,
    year_nbr * 10 + quarter_nbr as year_quarter_nbr,

    bimester_nbr,
    bimester_nbr || 'O BIMESTRE' as bimester_nm,
    year_nbr * 100 + bimester_nbr as year_bimester_nbr,

    month_nbr,
    (array['{{ month_names | join("', '") }}'])[month_nbr] as month_nm,
    (array['{{ month_abbrs | join("', '") }}'])[month_nbr] as month_abbr_nm,
    year_nbr * 100 + month_nbr as year_month_nbr,
    (array['{{ month_abbrs | join("', '") }}'])[month_nbr] || '/' || year_nbr as year_month_desc,
    extract(day from month_end_dt)::integer as days_in_month_qtty,
    month_start_dt,
    month_end_dt,
    (date_dt = month_start_dt) as month_start_flg,
    (date_dt = month_end_dt) as month_end_flg,

    iso_year_nbr,
    iso_week_nbr,
    iso_year_nbr * 100 + iso_week_nbr as year_week_nbr,
    (date_dt - (day_of_week_nbr - 1))::date as week_start_dt,
    (date_dt + (7 - day_of_week_nbr))::date as week_end_dt,

    day_nbr,
    extract(doy from date_dt)::integer as day_of_year_nbr,
    day_of_week_nbr,
    (array['{{ weekday_names | join("', '") }}'])[day_of_week_nbr] as day_of_week_nm,
    (array['{{ weekday_abbrs | join("', '") }}'])[day_of_week_nbr] as day_of_week_abbr_nm,
    (day_of_week_nbr in (6, 7)) as weekend_flg,
    (h.holiday_date is not null) as holiday_flg,
    coalesce(h.holiday_name, {{ not_applicable() }}) as holiday_nm
from enriched
left join holidays h on h.holiday_date = enriched.date_dt
