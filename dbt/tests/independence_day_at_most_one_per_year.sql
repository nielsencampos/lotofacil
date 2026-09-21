-- There is one Lotofacil da Independencia draw per year. Fails (returns the
-- offending years) if independence_day_flg ever flags more than one contest
-- in a year, i.e. if the rule in dim_contest starts over-flagging.
select
    d.year_nbr,
    count(*) as flagged_contests_qtty
from {{ ref('dim_contest') }} c
inner join {{ ref('dim_date') }} d on d.dim_date_id = c.draw_dim_date_id
where c.independence_day_flg
group by d.year_nbr
having count(*) > 1
