-- fact_sales.sql
-- PURPOSE: Sales fact table — one row per order line item.
-- Grain: one product sold in one order.
--
-- TODO: Join stg_order_items to stg_orders to build the fact table.
--   Required output columns:
--       item_id          -- surrogate key for this fact row (from order items)
--       order_id         -- FK to the order
--       order_date       -- date of the order (from stg_orders)
--       customer_id      -- FK → dim_customer
--       store_id         -- FK (store dimension not built — keep as raw ID for now)
--       product_id       -- FK → dim_product
--       payment_method   -- from stg_orders
--       quantity         -- from stg_order_items
--       unit_price       -- from stg_order_items
--       line_total       -- quantity * unit_price (already computed in staging)
--
-- HINT: JOIN stg_order_items ON stg_orders USING (order_id).
--   stg_order_items is the "left" table (the grain); stg_orders adds context.

WITH order_items AS (
    SELECT * FROM {{ ref('stg_order_items') }}
),

orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
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
FROM order_items  oi
JOIN orders       o  USING (order_id)
