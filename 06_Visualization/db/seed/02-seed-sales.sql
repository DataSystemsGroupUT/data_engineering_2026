-- Fictional supermarket observations for visualization, not real transactions.
-- One fact row represents one date + region + product category combination.
-- The dimensional model is represented here by two small lookup tables and a
-- dated fact table. The view at the end is the serving layer for both apps.

CREATE SCHEMA analytics;

CREATE TABLE analytics.dim_store (
    store_key integer PRIMARY KEY,
    store_name text NOT NULL,
    region text NOT NULL
);

INSERT INTO analytics.dim_store (store_key, store_name, region) VALUES
    (1, 'Tallinn store', 'North'),
    (2, 'Tartu store', 'South'),
    (3, 'Pärnu store', 'West');

CREATE TABLE analytics.dim_product (
    product_key integer PRIMARY KEY,
    product_name text NOT NULL,
    category text NOT NULL,
    unit_price_eur numeric(10, 2) NOT NULL
);

INSERT INTO analytics.dim_product
    (product_key, product_name, category, unit_price_eur) VALUES
    (1, 'Apples', 'Fruit', 2.50),
    (2, 'Milk', 'Dairy', 3.20),
    (3, 'Bread', 'Bakery', 4.60),
    (4, 'Soap', 'Household', 8.00);

CREATE TABLE analytics.fact_sales (
    sale_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sale_date date NOT NULL,
    store_key integer NOT NULL REFERENCES analytics.dim_store(store_key),
    product_key integer NOT NULL REFERENCES analytics.dim_product(product_key),
    quantity integer NOT NULL CHECK (quantity > 0),
    sales_amount numeric(12, 2) NOT NULL CHECK (sales_amount >= 0)
);

-- Produce the same 92 days of data on every fresh setup (July–September 2026).
-- CROSS JOIN forms each date × store × product combination: 92 × 3 × 4 rows.
-- The small arithmetic rule creates varying quantities without a live API.
WITH combinations AS (
    SELECT
        day::date AS sale_date,
        store.store_key,
        product.product_key,
        product.unit_price_eur,
        1 + ((EXTRACT(DOY FROM day)::integer
              + store.store_key * 2 + product.product_key) % 5)
          + CASE WHEN store.region = 'South' THEN 1 ELSE 0 END AS quantity
    FROM generate_series(DATE '2026-07-01', DATE '2026-09-30', INTERVAL '1 day')
         AS dates(day)
    CROSS JOIN analytics.dim_store AS store
    CROSS JOIN analytics.dim_product AS product
)
INSERT INTO analytics.fact_sales
    (sale_date, store_key, product_key, quantity, sales_amount)
SELECT sale_date, store_key, product_key, quantity,
       quantity * unit_price_eur
FROM combinations
ORDER BY sale_date, store_key, product_key;

-- A BI tool should read this named view instead of rebuilding the joins in
-- every chart. It stays at the original one-row-per-observation grain.
CREATE VIEW analytics.sales_enriched AS
SELECT
    sale.sale_id,
    sale.sale_date,
    store.region,
    product.category,
    sale.quantity,
    sale.sales_amount
FROM analytics.fact_sales AS sale
JOIN analytics.dim_store AS store ON sale.store_key = store.store_key
JOIN analytics.dim_product AS product ON sale.product_key = product.product_key;

-- Superset and Streamlit share this read-only view. They cannot edit the data.
GRANT USAGE ON SCHEMA analytics TO viz_reader;
GRANT SELECT ON analytics.sales_enriched TO viz_reader;
