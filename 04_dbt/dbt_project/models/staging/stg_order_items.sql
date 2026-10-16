-- stg_order_items.sql
-- PURPOSE: Clean and rename the raw_order_items seed table.
-- Each row is one product line within an order.
--
-- TODO: Select the following columns and add a derived column:
--   item_id                                   (keep as-is)
--   order_id                                  (keep as-is)
--   product_id                                (keep as-is)
--   quantity                                  (keep as-is)
--   unit_price                                (keep as-is)
--   quantity * unit_price  AS line_total      -- total revenue for this line
--
-- HINT: Use {{ ref('raw_order_items') }} as the source.

SELECT
    item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    quantity * unit_price AS line_total
FROM {{ ref('raw_order_items') }}
