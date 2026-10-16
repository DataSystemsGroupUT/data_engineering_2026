-- stg_orders.sql
-- PURPOSE: Clean and rename the raw_orders seed table.
--
-- TODO: Select the following columns and rename/cast as shown:
--   order_id                          (keep as-is)
--   customer_id                       (keep as-is)
--   store_id                          (keep as-is)
--   payment_method                    (keep as-is)
--   order_date::date  AS order_date
--
-- HINT: Use {{ ref('raw_orders') }} as the source.

SELECT
    order_id,
    customer_id,
    store_id,
    payment_method,
    order_date::date AS order_date
FROM {{ ref('raw_orders') }}
