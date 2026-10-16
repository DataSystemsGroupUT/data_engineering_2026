-- stg_customers.sql
-- PURPOSE: Clean and rename the raw_customers seed table.
-- This is the source of truth for the customer dimension.
-- The updated_at column will drive SCD2 tracking in the snapshot.
--
-- TODO: Select the following columns and rename/cast as shown:
--   customer_id                       (keep as-is)
--   first_name                        (keep as-is)
--   last_name                         (keep as-is)
--   email                             (keep as-is)
--   city                              (keep as-is)
--   segment                           (keep as-is)
--   created_at::date  AS created_date
--   updated_at::date  AS updated_date
--
-- HINT: Use {{ ref('raw_customers') }} as the source.

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    city,
    segment,
    created_at::date  AS created_date,
    updated_at::date  AS updated_date
FROM {{ ref('raw_customers') }}
