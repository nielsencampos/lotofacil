-- Bronze layer: every scalar (non-list, non-nested) attribute from the raw
-- API payload, with its proper type and an English column name — but no
-- business logic, joins, or derived columns. Dropped because they carry no
-- information (verified across all 3784 contests): `numero` (always equal to
-- `contest_number`); `id` and `premiacaoContingencia` (always null);
-- `nomeTimeCoracaoMesSorte` (always blank), `numeroJogo` (always 8),
-- `tipoJogo` (always LOTOFACIL), `tipoPublicacao` (one value) and
-- `ultimoConcurso` (true on every row).
{{ config(post_hook=[
    "alter table {{ this }} drop constraint if exists {{ this.identifier }}_pkey",
    "alter table {{ this }} add primary key (contest_number)"
]) }}
select
    contest_number,
    (payload ->> 'acumulado')::boolean as is_accumulated,
    to_date(payload ->> 'dataApuracao', 'DD/MM/YYYY') as draw_date,
    to_date(payload ->> 'dataProximoConcurso', 'DD/MM/YYYY') as next_draw_date,
    (payload ->> 'exibirDetalhamentoPorCidade')::boolean as show_city_detail,
    (payload ->> 'indicadorConcursoEspecial')::integer as special_contest_indicator,
    payload ->> 'localSorteio' as draw_location,
    payload ->> 'nomeMunicipioUFSorteio' as draw_city_state,
    (payload ->> 'numeroConcursoAnterior')::integer as previous_contest_number,
    (payload ->> 'numeroConcursoFinal_0_5')::integer as final_contest_number_0_5,
    (payload ->> 'numeroConcursoProximo')::integer as next_contest_number,
    payload ->> 'observacao' as remarks,
    (payload ->> 'valorArrecadado')::numeric as collected_amount,
    (payload ->> 'valorAcumuladoConcurso_0_5')::numeric as accumulated_amount_0_5,
    (payload ->> 'valorAcumuladoConcursoEspecial')::numeric as special_accumulated_amount,
    (payload ->> 'valorAcumuladoProximoConcurso')::numeric as next_accumulated_amount,
    (payload ->> 'valorEstimadoProximoConcurso')::numeric as next_estimated_prize,
    (payload ->> 'valorSaldoReservaGarantidora')::numeric as guarantee_fund_balance,
    (payload ->> 'valorTotalPremioFaixaUm')::numeric as total_prize_tier_one_amount
from {{ source('transient', 'raw') }}
