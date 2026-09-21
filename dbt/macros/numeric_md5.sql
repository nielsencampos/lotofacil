{#
    Deterministic numeric surrogate key: md5 of the given columns, first 13
    hex chars (52 bits) cast to bigint. Unlike row_number(), the same input
    always produces the same id across rebuilds, so ids stay stable when new
    rows show up. 52 bits (not 64) on purpose: it stays below 2^53, so the id
    survives JavaScript/Excel/BI tools without losing precision. With ~2k
    rows the collision odds are negligible (~4e-10), and each model that uses
    this has a unique test on the id to catch one if it ever happens.

    NULLs are coalesced to a sentinel so (NULL, 'a') and ('a', NULL) can't
    hash to the same value.

    Usage: {{ numeric_md5(['city_nm', 'state_cd']) }} as dim_x_id
#}
{% macro numeric_md5(columns) %}
    ('x' || substr(md5(concat_ws('|'
        {%- for column in columns -%}
        , coalesce(cast({{ column }} as text), '<null>')
        {%- endfor -%}
    )), 1, 13))::bit(52)::bigint
{% endmacro %}
