{{ config(materialized='table') }}

-- fact_sales.sql
-- PURPOSE: Sales fact table — grain: one row per order line item.
--
-- This model simply promotes int_order_lines from a view into a table.
-- All join logic lives in int_order_lines (intermediate layer).
-- Keeping marts thin makes them easy to read and audit.

SELECT
    item_id,
    order_id,
    order_date,
    customer_id,
    store_id,
    product_id,
    payment_method,
    quantity,
    unit_price,
    line_total
FROM {{ ref('int_order_lines') }}
