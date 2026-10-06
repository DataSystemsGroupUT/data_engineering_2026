{{ config(materialized='view') }}

-- int_order_lines.sql
-- PURPOSE: Join order headers (stg_orders) with order lines (stg_order_items).
--
-- This is the Silver+ / Intermediate layer.
--
-- Materialized as a VIEW — no table is written to disk.
-- dbt recomputes this on every query against fact_sales.
-- Use a view here because:
--   - the join is cheap on this dataset
--   - we want fact_sales to always see the freshest staging data
--   - no need to store a redundant copy of joined data
--
-- The {{ config(materialized='view') }} overrides the project-level default
-- of 'table' set in dbt_project.yml. Other useful config options:
--
--   schema    = 'intermediate'          -- write to a different schema
--   alias     = 'order_lines'           -- rename the output object
--   tags      = ['intermediate']        -- group for selection
--   pre_hook  = "SET work_mem='256MB'"  -- SQL to run before this model builds
--   post_hook = "GRANT SELECT ON {{ this }} TO reporter" -- SQL after build
--
-- See: https://docs.getdbt.com/reference/model-configs

WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

order_items AS (
    SELECT * FROM {{ ref('stg_order_items') }}
)

SELECT
    oi.item_id,
    oi.order_id,
    o.order_date,
    o.customer_id,
    o.store_id,
    oi.product_id,
    o.payment_method,
    oi.quantity,
    oi.unit_price,
    oi.line_total
FROM order_items oi
JOIN orders o USING (order_id)
