-- stg_products.sql
-- PURPOSE: Clean and rename the raw_products seed table.
--
-- TODO: Select the following columns:
--   product_id    (keep as-is)
--   product_name  (keep as-is)
--   category      (keep as-is)
--   brand         (keep as-is)
--   unit_price    (keep as-is — it is a NUMERIC from the seed)
--
-- HINT: Use {{ ref('raw_products') }} as the source.

SELECT
    product_id,
    product_name,
    category,
    brand,
    unit_price
FROM {{ ref('raw_products') }}
