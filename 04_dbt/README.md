# 🏗️ dbt Practice — Data Transformation with dbt and PostgreSQL

Practice session for the University of Tartu Data Engineering course.

You will use **dbt (data build tool)** to transform raw transactional data into
a dimensional star schema, test data quality, track historical changes with
SCD Type 2 snapshots, and orchestrate the pipeline with **Apache Airflow**.

---

## 🎯 Learning objectives

By the end of this session you will be able to:

1. Load raw seed data into PostgreSQL with `dbt seed`
2. Write staging models that clean and rename source tables
3. Build dimension and fact models that join staging tables into a star schema
4. Define and run schema tests (`not_null`, `unique`, `relationships`,
   `accepted_values`) and custom singular tests
5. Use dbt **selectors** to run a specific layer of models
6. Create a **snapshot** to track SCD Type 2 changes in a dimension table
7. Trigger the full pipeline from an **Airflow DAG**

---

## 🏛️ Architecture

```
PostgreSQL (retail-db, port 5434)
  └── schema: public_raw  ← dbt seed loads CSVs here
  └── schema: public      ← staging + mart models materialised here
  └── schema: snapshots   ← dbt snapshot writes here

dbt container             ← students run all dbt commands here (Steps 2–7)

Airflow (port 8080)       ← orchestrates the full pipeline (Step 8)
  └── DAG: dbt_pipeline
        dbt_seed → dbt_run_staging → dbt_run_marts → dbt_test → dbt_snapshot
```

---

## ✅ Prerequisites

- Docker Desktop, Colima, or Docker Engine + Compose plugin
- ~4 GB RAM available to Docker
- ~2 GB disk for images and database files

---

## 🚀 Setup

### 1. Build and start the stack

Run these commands from the `04_dbt/` directory:

```bash
cp .env_example .env        # copy environment defaults (no edits needed)
docker compose build        # build the custom Airflow image with dbt pre-installed
docker compose up -d        # start all services in the background
```

The first `docker compose build` takes 2–3 minutes (builds two images: a
lightweight dbt image and the Airflow image). Subsequent starts are fast.

### 2. Wait for Airflow to be ready

Airflow runs a one-off initialisation container (`airflow-init`) that migrates
the metadata database and creates the admin user. This takes about 30–60 seconds.

Check that all containers are healthy:

```bash
docker compose ps
```

All services should show `healthy` or `running`.  
If `dbt-airflow-init` shows `exited (0)` that is correct — it exits after finishing.

### 3. Services

| Service       | URL / connection               | Credentials                 |
|---------------|--------------------------------|-----------------------------|
| dbt           | `docker compose run --rm dbt`  | —                           |
| Airflow UI    | http://localhost:8080           | airflow / airflow           |
| pgAdmin       | http://localhost:5051           | admin@example.com / admin   |
| retail-db     | host `localhost`, port `5434`  | retail_user / retail_pass   |
| airflow-db    | host `localhost`, port `5435`  | airflow / airflow           |

### 4. Connect pgAdmin to retail-db

pgAdmin runs inside Docker, so it connects to other containers by their
**service name**, not `localhost`.

In pgAdmin → Object → Register → Server:

- **General tab → Name**: `retail-db`
- **Connection tab**:
  - **Host name / address**: `retail-db`  ← service name inside Docker
  - **Port**: `5432`                       ← internal port (not 5434)
  - **Maintenance database**: `retail_db`
  - **Username**: `retail_user`
  - **Password**: `retail_pass`

> **Note:** If you connect from a tool on your own machine (e.g., psql, DBeaver,
> DataGrip), use `localhost` and port `5434` instead.

---

## 📊 Data model

The source data lives in `dbt_project/seeds/` as CSV files.
These simulate a production OLTP database (one row per business event — no
surrogate keys, no pre-computed totals).

```
raw_customers   ← customer master (name, city, segment, updated_at) → public_raw.raw_customers
raw_products    ← product catalogue (name, category, brand, unit_price) → public_raw.raw_products
raw_stores      ← store locations → public_raw.raw_stores
raw_orders      ← order headers (customer_id, store_id, payment_method, date) → public_raw.raw_orders
raw_order_items ← order lines   (order_id, product_id, quantity, unit_price) → public_raw.raw_order_items
```

> Seeds land in the `public_raw` schema (dbt appends the `raw` prefix to the
> default schema `public`). Staging and mart models land in `public`.

The target star schema you will build:

```
dim_customer ──┐
               ├── fact_sales
dim_product  ──┘
```

Grain of `fact_sales`: **one row per order line item** (one product in one order).

---

## 📁 Project structure

```
dbt_project/
├── seeds/                  raw CSVs loaded by dbt seed
├── models/
│   ├── staging/            clean + rename raw seed tables
│   │   ├── schema.yml      tests for staging models
│   │   └── stg_*.sql
│   └── marts/              dimension and fact tables
│       ├── schema.yml      tests for mart models
│       ├── dim_*.sql
│       └── fact_sales.sql
├── snapshots/              SCD Type 2 history tracking
├── tests/                  custom singular tests
├── selectors.yml           named model selectors
├── profiles.yml            database connection config
└── dbt_project.yml         project settings
```

---

## 🧪 Step-by-step exercises

Work through the steps in order — each one builds on the previous.

---

### Step 1 — Explore the seed data

Open `dbt_project/seeds/` and read the five CSV files. Answer these questions:

- What is the natural key (business identifier) of each table?
- Which columns would you rename or cast to a different type?
- Which column in `raw_customers` should drive SCD2 history tracking?

---

### Step 2 — Load seeds into the database

```bash
docker compose run --rm dbt seed
```

In pgAdmin, expand `retail_db → Schemas → public_raw → Tables`.
You should see five tables: `raw_customers`, `raw_products`, `raw_stores`,
`raw_orders`, `raw_order_items`.

---

### Step 3 — Write staging models

Open `dbt_project/models/staging/`.
Each `.sql` file has inline `TODO` comments that guide you through the changes.

Complete them in this order:

1. **`stg_customers.sql`** — cast `updated_at` to date; other columns pass through
2. **`stg_products.sql`** — all columns pass through
3. **`stg_orders.sql`** — cast `order_date` to date
4. **`stg_order_items.sql`** — add `line_total = quantity * unit_price`

Run the staging layer to check your work:

```bash
docker compose run --rm dbt run --selector staging_models
```

Run tests for the staging layer:

```bash
docker compose run --rm dbt test --selector staging_models
```

Fix any failures before moving on.

---

### Step 4 — Write mart models

Open `dbt_project/models/marts/`.
Complete the three models in this order:

1. **`dim_product.sql`** — simple passthrough from `stg_products` (easiest)
2. **`dim_customer.sql`** — use `ROW_NUMBER()` to keep only the latest record
   per `customer_id` (handles re-seeding with updated data)
3. **`fact_sales.sql`** — `JOIN stg_order_items` to `stg_orders` on `order_id`

Each file has `TODO` comments explaining exactly what columns to include.

Run the marts layer:

```bash
docker compose run --rm dbt run --selector mart_models
```

---

### Step 5 — Run data quality tests 🔍

```bash
docker compose run --rm dbt test
```

Tests are defined in two files:

- `models/staging/schema.yml` — tests for all staging models
- `models/marts/schema.yml` — tests for dim_customer, dim_product, fact_sales

They cover:
- `not_null` and `unique` on every primary key
- `relationships` — FK columns in `fact_sales` must exist in the dimension tables
- `accepted_values` on `segment` (Regular, VIP, Premium)

A custom singular test lives in `tests/check_pos_total_sales.sql`:
it fails (returns rows) if any `line_total` in `fact_sales` is zero or negative.

Fix any failures before moving on.

---

### Step 6 — Understand selectors

Open `dbt_project/selectors.yml`.
Three selectors are defined: `staging_models`, `mart_models`, `all_models`.

Run all models in one command using `all_models`:

```bash
docker compose run --rm dbt run --selector all_models
```

> **Why selectors?**
> In production you often want to refresh only one layer at a time — for example,
> re-run marts after a hotfix without repeating the seed or staging steps.
> The Airflow DAG in this session uses selectors for exactly that purpose.

---

### Step 7 — Take a snapshot (SCD Type 2) 📸

Run the snapshot:

```bash
docker compose run --rm dbt snapshot
```

Read `dbt_project/snapshots/dim_customer_snapshot.sql` to understand how it works.

In pgAdmin, expand `retail_db → Schemas → snapshots → Tables → dim_customer_snapshot`.
You should see **8 rows** — one per customer, all with `dbt_valid_to = NULL`
(meaning all records are currently active).

The columns `dbt_valid_from` and `dbt_valid_to` are added automatically by dbt.

---

### Step 8 — Trigger the full pipeline from Airflow 🌀

1. Open the Airflow UI: http://localhost:8080  (airflow / airflow)
2. Find the DAG **`dbt_pipeline`**
3. Toggle it on (unpause) using the switch on the left
4. Click **Trigger DAG** (▶ button on the right)
5. Click the DAG run row to watch the task graph

The five tasks run in sequence:

```
dbt_seed → dbt_run_staging → dbt_run_marts → dbt_test → dbt_snapshot
```

Click any green task → **Log** to see the full dbt output for that step.

---

## 📖 Appendix: SCD Type 2 — tracking customer changes

This exercise simulates a business event where two customers update their
profile, and you observe how the snapshot captures the history.

### What changes

The file `data/raw_customers_update.csv` contains the full 8-customer list with
two differences from the original seed:

| customer_id | Name  | What changed             | updated_at  |
|-------------|-------|--------------------------|-------------|
| 1           | Alice | segment: Regular → **VIP** | 2024-06-01 |
| 4           | David | city: Pärnu → **Tartu**    | 2024-06-01 |

### A. Apply the update

Replace the original seed file with the update batch:

```bash
cp data/raw_customers_update.csv dbt_project/seeds/raw_customers.csv
```

### B. Re-seed, refresh staging, and re-snapshot

```bash
# 1. Reload the seed table with the updated customer data
docker compose run --rm dbt seed --full-refresh

# 2. Re-run staging so stg_customers reflects the new updated_date values
docker compose run --rm dbt run --selector staging_models

# 3. Run the snapshot — it will detect changed rows and write history
docker compose run --rm dbt snapshot
```

`--full-refresh` drops and recreates the seed table so updated rows replace the originals.
The snapshot compares the current `stg_customers` data to its stored copy and:
- **Closes** old rows (sets `dbt_valid_to = new updated_date`)
- **Inserts** new rows with `dbt_valid_to = NULL` (current record)

### C. Query the snapshot history

Run this query in pgAdmin (Tools → Query Tool):

```sql
SELECT
    customer_id,
    first_name,
    city,
    segment,
    dbt_valid_from,
    dbt_valid_to
FROM snapshots.dim_customer_snapshot
WHERE customer_id IN (1, 4)
ORDER BY customer_id, dbt_valid_from;
```

Expected result — two rows per changed customer:

```
 customer_id | first_name | city    | segment | dbt_valid_from | dbt_valid_to
-------------+------------+---------+---------+----------------+--------------
 1           | Alice      | Tallinn | Regular | 2024-01-10     | 2024-06-01
 1           | Alice      | Tallinn | VIP     | 2024-06-01     | NULL
 4           | David      | Pärnu   | Premium | 2024-02-14     | 2024-06-01
 4           | David      | Tartu   | Premium | 2024-06-01     | NULL
```

- `dbt_valid_to = NULL` → current (active) record
- `dbt_valid_to = <date>` → historical (closed) record

### D. Run the Airflow DAG again

Re-trigger the `dbt_pipeline` DAG from the Airflow UI.
This re-runs the entire pipeline — seed → staging → marts → test → snapshot —
showing how a scheduled DAG keeps the dimensional model in sync with source changes.

---

## 🛑 Stopping the stack

```bash
docker compose down
```

To remove all database data and start completely fresh:

```bash
docker compose down -v
rm -rf pgdata_retail pgdata_airflow logs
```
