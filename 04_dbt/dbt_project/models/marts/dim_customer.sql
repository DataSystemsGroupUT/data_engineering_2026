-- dim_customer.sql
-- PURPOSE: Customer dimension table (SCD Type 1 — current state only).
-- For historical tracking see snapshots/dim_customer_snapshot.sql.
--
-- TODO: Build the customer dimension from stg_customers.
--   - Use ROW_NUMBER() partitioned by customer_id, ordered by updated_date DESC
--     to pick only the latest record per customer (handles future re-seeds).
--   - Assign a surrogate key using dbt_utils.generate_surrogate_key(...)
--     OR simply cast customer_id as the key for now.
--   - Output columns:
--       customer_id, first_name, last_name, email, city, segment,
--       created_date, updated_date
--
-- HINT: Use a CTE with ROW_NUMBER() to deduplicate, then SELECT WHERE rn = 1.

WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY updated_date DESC
        ) AS rn
    FROM {{ ref('stg_customers') }}
)

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    city,
    segment,
    created_date,
    updated_date
FROM ranked
WHERE rn = 1
