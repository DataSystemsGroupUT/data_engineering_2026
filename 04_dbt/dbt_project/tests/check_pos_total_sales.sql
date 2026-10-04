-- Custom singular test: every line_total in fact_sales must be positive.
-- A negative line_total would indicate a data error in the seed or staging.
-- This test FAILS (returns rows) if any line_total is zero or negative.

SELECT *
FROM {{ ref('fact_sales') }}
WHERE line_total <= 0
