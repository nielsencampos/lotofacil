{#
    bronze.winning_municipalities (and, less often, bronze.draws) has a few
    known-bad state/city values these macros canonicalize:
    - Accents are stripped via Postgres's `unaccent` extension (see the
      on-run-start hook in dbt_project.yml) so e.g. "MACEIO" and "MACEIO"
      collapse — plain regex substitution would need a hand-rolled list of
      every accented character; unaccent handles all of them correctly.
    - (state='--', city='CANAL ELETRONICO') and (state='XX', city='Canal
      Eletrônico') both mean online/app ticket sales with no physical
      municipality -> canonicalized to state='XX' (the city side already
      collapses to the same value once unaccented).
    - state='C' (city='Fortaleza', the capital of Ceará) -> truncated 'CE'.
    - state='G' (city='Santa Helena de Goias', a city in Goiás) -> truncated
      'GO'.
    - A blank city (e.g. some winning tickets have a state but no city on
      record) is filled in as '---NAO INFORMADO---'.
    Apply to every state/city column that ends up in dim_municipality
    (bronze.winning_municipalities AND the parsed bronze.draws.draw_city_state)
    so they all collapse consistently and the dimension's FKs hold.
#}
{% macro normalize_municipality_state(state_col, city_col) %}
    case
        when upper(trim({{ state_col }})) = '--'
          or unaccent(upper(trim({{ city_col }}))) = 'CANAL ELETRONICO'
            then 'XX'
        when upper(trim({{ state_col }})) = 'C' then 'CE'
        when upper(trim({{ state_col }})) = 'G' then 'GO'
        else upper(trim({{ state_col }}))
    end
{% endmacro %}

{% macro normalize_municipality_city(city_col) %}
    case
        when trim({{ city_col }}) = '' then '---NAO INFORMADO---'
        else unaccent(upper(trim({{ city_col }})))
    end
{% endmacro %}
