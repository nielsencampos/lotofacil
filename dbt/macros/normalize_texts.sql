{#
    Text normalization, plus the location-specific rules for everything that
    ends up in dim_location: the draw venue/city/state parsed from
    bronze.draws AND the winning-ticket state/city from
    bronze.winning_municipalities. dim_location, dim_contest and
    fact_winning_municipalities all run these same macros, so the joins
    between them keep matching — never inline the expressions instead.

    - normalize_text(): upper + trim + strip accents. Accents go through
      Postgres's `unaccent` extension (see the on-run-start hook in
      dbt_project.yml) so e.g. "MACEIO" and "MACEIÓ" collapse — a regex would
      need a hand-rolled list of every accented character.
    - A blank location/city is filled in as '---NAO INFORMADO---'
      (not_informed()).
    - Draw venues (draw_location) have typos and word-order variants in the
      source, so normalize_location_nm() maps the known ones to a canonical
      name (see the alias map inside it). Only 6 values are expected in
      dim_location.location_nm; an accepted_values test on it fails when a
      new, unmapped variant shows up so it gets a conscious decision.
    - (state='--', city='CANAL ELETRONICO') and (state='XX', city='Canal
      Eletrônico') both mean online/app ticket sales with no physical
      municipality -> canonicalized to state='XX' (the city side already
      collapses to the same value once normalized).
    - state='C' (city='Fortaleza', the capital of Ceará) -> truncated 'CE'.
    - state='G' (city='Santa Helena de Goias', a city in Goiás) -> truncated
      'GO'.
#}

{% macro normalize_text(col) %}unaccent(upper(trim({{ col }}))){% endmacro %}

{% macro not_informed() %}'---NAO INFORMADO---'{% endmacro %}

{% macro normalize_location_nm(location_col) %}
    {#- keys are already normalized (upper, no accents); values are canonical -#}
    {%- set aliases = {
        'CAMINHAO DA SORTE09': 'CAMINHAO DA SORTE',
        'AUDITORIO 512 NORTE': 'AUDITORIO',
        'CAMINHAO DO SORTE': 'CAMINHAO DA SORTE',
        'ESPACO CAIXA LOTERIAS': 'ESPACO LOTERIAS CAIXA',
        'ESPACO LOTERIA CAIXA': 'ESPACO LOTERIAS CAIXA',
        'ESPCACO LOTERIAS CAIXA': 'ESPACO LOTERIAS CAIXA',
        'ESAPCO LOTERIAS CAIXA': 'ESPACO LOTERIAS CAIXA',
        'ESPCAO LOTERIAS CAIXA': 'ESPACO LOTERIAS CAIXA',
        'ESPACO LOOTERIAS CAIXA': 'ESPACO LOTERIAS CAIXA',
        'ESPACO LOETRIAS CAIXA': 'ESPACO LOTERIAS CAIXA',
        'ESPACO LOTERIAS CAICA': 'ESPACO LOTERIAS CAIXA',
        'ESTUDIO DE TV.': 'ESTUDIO DE TV',
    } -%}
    case
        when trim({{ location_col }}) = '' then {{ not_informed() }}
        else
            case {{ normalize_text(location_col) }}
                {%- for raw, canonical in aliases.items() %}
                when '{{ raw }}' then '{{ canonical }}'
                {%- endfor %}
                else {{ normalize_text(location_col) }}
            end
    end
{% endmacro %}

{% macro normalize_city_nm(city_col) %}
    case
        when trim({{ city_col }}) = '' then {{ not_informed() }}
        else {{ normalize_text(city_col) }}
    end
{% endmacro %}

{% macro normalize_state_cd(state_col, city_col) %}
    case
        when {{ normalize_text(state_col) }} = '--'
          or {{ normalize_text(city_col) }} = 'CANAL ELETRONICO'
            then 'XX'
        when {{ normalize_text(state_col) }} = 'C' then 'CE'
        when {{ normalize_text(state_col) }} = 'G' then 'GO'
        else {{ normalize_text(state_col) }}
    end
{% endmacro %}
