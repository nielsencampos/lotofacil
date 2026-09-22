-- Gold bridge: one row per pair of contests that drew at least 13 of the
-- same 15 balls. Two random contests already share ~9 balls by chance (each
-- draws 15 of 25), so 11+ or 12+ is most of the ~7.2M possible pairs
-- (760k, 11% of them) and not a meaningfully "similar" draw -- 13+ is the
-- tail worth looking at (about 10.7k pairs).
-- - contest_a_nbr is always the earlier contest, contest_b_nbr the later one
--   (contest numbers increase over time), so each pair appears once, never
--   as both (a, b) and (b, a).
-- - shared_ball_qtty is 13 to 15; 15 means the two contests drew the exact
--   same 15 balls -- an identical repeat. shared_balls lists which balls, in
--   ascending order.
-- - Built directly from silver (fact_ball_draws self-joined on the ball,
--   across contests), not from cube_contest, matching the rule that gold
--   tables are independent of each other.
-- - Date, venue and the tier-15 winner info are unfolded per contest (a/b),
--   the same convenience cube_contest gives its reader, and the winning
--   municipalities are handled exactly like cube_contest does: winner_qtty
--   is a plain count of tier-15 winners (always present, so inner join),
--   winning_locations is the same source's per-municipality breakdown
--   (a contest can have none, so left join + coalesce to 0 / '[]'). Only
--   tier 15 (the top prize) is unfolded -- the other tiers aren't about the
--   pair's similarity.
-- The primary key is the pair (contest_a_nbr, contest_b_nbr); left unnamed
-- for the same reason noted in dim_location.sql.
{{ config(
    tags=["similarity"],
    post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (contest_a_nbr, contest_b_nbr)"
]) }}
{%- set min_shared_balls = 13 %}
with fact_ball_draws as (
    select
        dim_contest_id,
        dim_ball_id
    from {{ ref('fact_ball_draws') }}
),

dim_ball as (
    select
        dim_ball_id,
        ball_nbr
    from {{ ref('dim_ball') }}
),

dim_contest as (
    select
        dim_contest_id,
        contest_nbr,
        draw_dim_date_id,
        dim_location_id
    from {{ ref('dim_contest') }}
),

dim_date as (
    select
        dim_date_id,
        date_dt
    from {{ ref('dim_date') }}
),

dim_location as (
    select
        dim_location_id,
        location_nm,
        city_nm,
        state_cd
    from {{ ref('dim_location') }}
),

fact_prize_tiers as (
    select
        dim_contest_id,
        dim_prize_tier_id,
        winner_qtty
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

pairs as (
    select
        a.dim_contest_id as dim_contest_a_id,
        b.dim_contest_id as dim_contest_b_id,
        count(*) as shared_ball_qtty,
        array_agg(dbl.ball_nbr order by dbl.ball_nbr) as shared_balls
    from fact_ball_draws a
    inner join fact_ball_draws b
        on b.dim_ball_id = a.dim_ball_id
       and b.dim_contest_id > a.dim_contest_id
    inner join dim_ball dbl on dbl.dim_ball_id = a.dim_ball_id
    group by a.dim_contest_id, b.dim_contest_id
    having count(*) >= {{ min_shared_balls }}
),

tier_15_winners as (
    select
        fpt.dim_contest_id,
        fpt.winner_qtty as tier_15_winner_qtty
    from fact_prize_tiers fpt
    inner join dim_prize_tier dpt on dpt.dim_prize_tier_id = fpt.dim_prize_tier_id
    where dpt.prize_tier_nbr = 15
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
    ca.contest_nbr as contest_a_nbr,
    cb.contest_nbr as contest_b_nbr,

    p.shared_ball_qtty,
    p.shared_balls,
    
    da.date_dt as contest_a_draw_dt,
    db.date_dt as contest_b_draw_dt,

    la.location_nm as contest_a_location_nm,
    la.city_nm as contest_a_city_nm,
    la.state_cd as contest_a_state_cd,
    lb.location_nm as contest_b_location_nm,
    lb.city_nm as contest_b_city_nm,
    lb.state_cd as contest_b_state_cd,

    t15a.tier_15_winner_qtty as contest_a_tier_15_winner_qtty,
    coalesce(ma.tier_15_winning_municipality_qtty, 0) as contest_a_tier_15_winning_municipality_qtty,
    coalesce(ma.tier_15_winning_locations, '[]'::jsonb) as contest_a_tier_15_winning_locations,
    
    t15b.tier_15_winner_qtty as contest_b_tier_15_winner_qtty,
    coalesce(mb.tier_15_winning_municipality_qtty, 0) as contest_b_tier_15_winning_municipality_qtty,
    coalesce(mb.tier_15_winning_locations, '[]'::jsonb) as contest_b_tier_15_winning_locations
from pairs p
inner join dim_contest ca on ca.dim_contest_id = p.dim_contest_a_id
inner join dim_contest cb on cb.dim_contest_id = p.dim_contest_b_id
inner join dim_date da on da.dim_date_id = ca.draw_dim_date_id
inner join dim_date db on db.dim_date_id = cb.draw_dim_date_id
inner join dim_location la on la.dim_location_id = ca.dim_location_id
inner join dim_location lb on lb.dim_location_id = cb.dim_location_id
inner join tier_15_winners t15a on t15a.dim_contest_id = ca.dim_contest_id
inner join tier_15_winners t15b on t15b.dim_contest_id = cb.dim_contest_id
left join municipalities ma on ma.dim_contest_id = ca.dim_contest_id
left join municipalities mb on mb.dim_contest_id = cb.dim_contest_id
