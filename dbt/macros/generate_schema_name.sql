{#
    dbt's default behavior prefixes a custom schema with the target schema
    (e.g. "public_bronze"). We want the custom schema name used as-is
    (e.g. "bronze"), so every layer gets its own top-level schema.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
