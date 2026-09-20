{#
    Generic test for composite primary keys (dbt's built-in `unique` test
    only supports a single column). Usage in a schema.yml, at the model
    level:

        data_tests:
          - unique_combination_of_columns:
              combination_of_columns: [contest_number, draw_order]
#}
{% test unique_combination_of_columns(model, combination_of_columns) %}

with duplicates as (
    select
        {{ combination_of_columns | join(', ') }},
        count(*) as row_count
    from {{ model }}
    group by {{ combination_of_columns | join(', ') }}
    having count(*) > 1
)

select * from duplicates

{% endtest %}
