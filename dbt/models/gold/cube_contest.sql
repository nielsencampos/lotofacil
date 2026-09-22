-- Gold cube: one row per contest with everything about it in one place, so it
-- can be read without a single join. Built only from silver (no logic that
-- silver doesn't already hold), it exists for convenience of the reader:
-- BI, notebooks, quick questions like "which contests had these balls".
-- - The key is contest_nbr, the natural key: a gold table is read, not joined
--   to, so it carries none of the silver surrogate ids.
-- - balls_draw_order lists the 15 drawn balls in the order they came out
--   (position 1 first); balls_sorted lists the same balls in numeric order.
-- - The prize tiers are pivoted into columns (tier_15_* = 15 hits ... tier_11_*
--   = 11 hits): the winners and the prize each one won. winner_total_qtty adds
--   the winners of every tier.
-- - tier_15_winning_municipality_qtty and tier_15_winning_locations come from the
--   winning municipalities fact: one JSON entry per source row, with city, state
--   and winners, in source order. The source does not say which tier that list
--   is for, but it only exists for contests with a 15-hit winner (all 3,301 of
--   them) and never for the others, so it is the top tier's list and named so;
--   tiers 11 to 14 have no location data at all. It is NOT reconciled with
--   tier_15_winner_qtty: the two sums differ in 79 contests, so both are shown
--   as the source sent them. Contests without entries get 0 and an empty list.
-- - Dates are unfolded from dim_date for the draw day (and the next draw's
--   date) so the day of the week and the holiday are right there.
-- The primary key is unnamed on purpose — see the note in dim_location.sql.
{{ config(
    tags=["cube"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (contest_nbr)"
]) }}
{%- set tiers = [15, 14, 13, 12, 11] %}
with fact_ball_draws as (
    select
        dim_contest_id,
        dim_draw_position_id,
        dim_ball_id
    from {{ ref('fact_ball_draws') }}
),

dim_ball as (
    select
        dim_ball_id,
        ball_nbr
    from {{ ref('dim_ball') }}
),

dim_draw_position as (
    select
        dim_draw_position_id,
        draw_position_nbr
    from {{ ref('dim_draw_position') }}
),

fact_prize_tiers as (
    select
        dim_contest_id,
        dim_prize_tier_id,
        winner_qtty,
        prize_amt
    from {{ ref('fact_prize_tiers') }}
),

dim_prize_tier as (
    select
        dim_prize_tier_id,
        prize_tier_nbr
    from {{ ref('dim_prize_tier') }}
),

fact_winning_municipalities as (
    select
        dim_contest_id,
        dim_location_id,
        winner_index_nbr,
        winner_qtty
    from {{ ref('fact_winning_municipalities') }}
),

dim_location as (
    select
        dim_location_id,
        location_nm,
        city_nm,
        state_cd
    from {{ ref('dim_location') }}
),

dim_contest as (
    select
        contest_nbr,
        dim_contest_id,
        draw_dim_date_id,
        next_draw_dim_date_id,
        dim_location_id,
        is_accumulated_flg,
        show_city_detail_flg,
        independence_day_flg,
        remarks_desc,
        previous_contest_nbr,
        final_contest_nbr,
        next_contest_nbr
    from {{ ref('dim_contest') }}
),

dim_date as (
    select
        dim_date_id,
        date_dt,
        day_of_week_nm,
        year_nbr,
        month_nbr,
        holiday_flg,
        holiday_nm
    from {{ ref('dim_date') }}
),

fact_contest_summary as (
    select
        dim_contest_id,
        collected_amt,
        accumulated_amt,
        special_accumulated_amt,
        next_accumulated_amt,
        next_estimated_prize_amt,
        guarantee_fund_balance_amt,
        total_prize_tier_one_amt
    from {{ ref('fact_contest_summary') }}
),

balls as (
    select
        fbd.dim_contest_id,
        array_agg(db.ball_nbr order by dp.draw_position_nbr) as balls_draw_order,
        array_agg(db.ball_nbr order by db.ball_nbr) as balls_sorted
    from fact_ball_draws fbd
    inner join dim_ball db on db.dim_ball_id = fbd.dim_ball_id
    inner join dim_draw_position dp
        on dp.dim_draw_position_id = fbd.dim_draw_position_id
    group by fbd.dim_contest_id
),

prize_tiers as (
    select
        fpt.dim_contest_id
        {%- for tier in tiers %},
        sum(fpt.winner_qtty) filter (where dpt.prize_tier_nbr = {{ tier }}) as tier_{{ tier }}_winner_qtty,
        sum(fpt.prize_amt) filter (where dpt.prize_tier_nbr = {{ tier }}) as tier_{{ tier }}_prize_amt
        {%- endfor %},
        sum(fpt.winner_qtty) as winner_total_qtty
    from fact_prize_tiers fpt
    inner join dim_prize_tier dpt on dpt.dim_prize_tier_id = fpt.dim_prize_tier_id
    group by fpt.dim_contest_id
),

municipalities as (
    select
        fwm.dim_contest_id,
        count(*) as tier_15_winning_municipality_qtty,
        jsonb_agg(
            jsonb_build_object(
                'city_nm', l.city_nm,
                'state_cd', l.state_cd,
                'winner_qtty', fwm.winner_qtty
            )
            order by fwm.winner_index_nbr
        ) as tier_15_winning_locations
    from fact_winning_municipalities fwm
    inner join dim_location l on l.dim_location_id = fwm.dim_location_id
    group by fwm.dim_contest_id
)

select
    c.contest_nbr,

    dd.date_dt as draw_dt,
    dd.day_of_week_nm as draw_day_of_week_nm,
    dd.year_nbr as draw_year_nbr,
    dd.month_nbr as draw_month_nbr,
    dd.holiday_flg as draw_holiday_flg,
    dd.holiday_nm as draw_holiday_nm,
    nd.date_dt as next_draw_dt,

    l.location_nm,
    l.city_nm,
    l.state_cd,

    c.is_accumulated_flg,
    c.show_city_detail_flg,
    c.independence_day_flg,
    c.remarks_desc,
    c.previous_contest_nbr,
    c.final_contest_nbr,
    c.next_contest_nbr,

    b.balls_draw_order,
    b.balls_sorted,

    {% for tier in tiers -%}
    pt.tier_{{ tier }}_winner_qtty,
    pt.tier_{{ tier }}_prize_amt,
    {% endfor -%}
    pt.winner_total_qtty,

    coalesce(m.tier_15_winning_municipality_qtty, 0) as tier_15_winning_municipality_qtty,
    coalesce(m.tier_15_winning_locations, '[]'::jsonb) as tier_15_winning_locations,

    s.collected_amt,
    s.accumulated_amt,
    s.special_accumulated_amt,
    s.next_accumulated_amt,
    s.next_estimated_prize_amt,
    s.guarantee_fund_balance_amt,
    s.total_prize_tier_one_amt
from dim_contest c
inner join dim_date dd on dd.dim_date_id = c.draw_dim_date_id
left join dim_date nd on nd.dim_date_id = c.next_draw_dim_date_id
inner join dim_location l on l.dim_location_id = c.dim_location_id
inner join balls b on b.dim_contest_id = c.dim_contest_id
inner join prize_tiers pt on pt.dim_contest_id = c.dim_contest_id
left join municipalities m on m.dim_contest_id = c.dim_contest_id
inner join fact_contest_summary s on s.dim_contest_id = c.dim_contest_id
