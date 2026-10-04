{% snapshot dim_customer_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_date'
    )
}}

-- This snapshot tracks changes to customer attributes over time (SCD Type 2).
--
-- When a customer's segment or city changes and the seed is re-loaded
-- with a newer updated_date, dbt snapshot will:
--   1. Close the old row by setting dbt_valid_to = new updated_date
--   2. Insert a new row with dbt_valid_to = NULL (current record)
--
-- Try it yourself (see the SCD2 Appendix in README.md):
--   1. Apply raw_customers_update.csv and re-run dbt seed
--   2. Run: dbt snapshot
--   3. Query: SELECT * FROM snapshots.dim_customer_snapshot ORDER BY customer_id, dbt_valid_from;

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    city,
    segment,
    created_date,
    updated_date
FROM {{ ref('stg_customers') }}

{% endsnapshot %}
