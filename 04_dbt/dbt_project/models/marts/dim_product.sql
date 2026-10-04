-- dim_product.sql
-- PURPOSE: Product dimension table (SCD Type 1 — no history tracked).
--
-- TODO: Select all columns from stg_products.
--   Output columns:
--       product_id, product_name, category, brand, unit_price
--
-- HINT: This is a simple passthrough from staging — one SELECT, no joins needed.

SELECT
    product_id,
    product_name,
    category,
    brand,
    unit_price
FROM {{ ref('stg_products') }}
