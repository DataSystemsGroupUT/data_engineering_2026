# 🏗️ dbt Practice — Data Transformation with dbt and PostgreSQL

Practice session for the University of Tartu Data Engineering course.

You will use **dbt (data build tool)** to transform raw transactional data into
a dimensional star schema using a Medallion architecture, test data quality,
track historical changes with SCD Type 2 snapshots, and orchestrate the
pipeline with **Apache Airflow**.

---

## 🎯 Learning objectives

By the end of this session you will be able to:

1. Load raw seed data into PostgreSQL with `dbt seed`
2. Write staging models that clean and rename source tables
3. Build an intermediate layer that joins and enriches staging data
4. Build dimension and fact models from the intermediate layer
5. Control how models are stored using `{{ config() }}`
6. Define and run schema tests and custom singular tests
7. Use dbt **selectors** to run a specific layer of models
8. Create a **snapshot** to track SCD Type 2 changes in a dimension table
9. Trigger the full pipeline from an **Airflow DAG**

---

## 🏛️ Architecture

```
PostgreSQL (retail-db, port 5434)
  └── schema: public_raw  ← dbt seed loads CSVs here
  └── schema: public      ← all models materialised here
  └── schema: snapshots   ← dbt snapshot writes here

dbt container             ← run all dbt commands here (Steps 2–8)

Airflow (port 8080)       ← orchestrates the full pipeline (Step 9)
  └── internal: airflow-db (port 5435) ← Airflow metadata only
  └── DAG: dbt_pipeline
        dbt_seed → dbt_run_staging → dbt_run_intermediate
                 → dbt_run_marts → dbt_test → dbt_snapshot
```

### Databases

There are two PostgreSQL 16 instances, kept intentionally separate:

| Database | Port | Purpose |
|---|---|---|
| **retail-db** | 5434 | Your data — seeds, models, snapshots. This is what you browse in pgAdmin and query. |
| **airflow-db** | 5435 | Airflow's internal metadata — DAG definitions, task run history, connections, logs. We never interact with this directly. |

**Why two databases?** In production, the orchestrator (Airflow) and the data warehouse are always separate systems. Mixing them would mean Airflow's own bookkeeping tables live alongside your business data, making both harder to manage, back up, or scale independently. This setup mirrors that real-world separation at a small scale.

**Storage format — row-oriented PostgreSQL**

Both databases use standard PostgreSQL 16 with row-oriented (heap) storage — the default for transactional (OLTP) workloads. In the real world, the analytical target is often backed by **columnar storage**, where each column is stored separately, making aggregate queries much faster.

Examples of columnar storage used in production:

| System | Type |
|---|---|
| **Snowflake** | Cloud-native columnar data warehouse |
| **BigQuery** (Google) | Columnar, serverless |
| **Redshift** (AWS) | Columnar with distribution keys |
| **ClickHouse** | Open-source columnar (see `archive/05_ClickHouse`) |
| **Citus columnar** | PostgreSQL extension — `USING columnar` |
| **DuckDB** | Embedded columnar, popular for local analytics |
| **Apache Iceberg + Parquet** | Open columnar file format (see `archive/08_Iceberg`) |

The dbt skills you learn here transfer to any of these — change the adapter in `profiles.yml` (`type: snowflake`, `type: bigquery`, etc.).

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
docker compose build        # build the dbt image and the Airflow image
docker compose up -d        # start all services in the background
```

The first `docker compose build` takes 2–3 minutes. Subsequent starts are fast.

### 2. Wait for Airflow to be ready

Airflow runs a one-off init container (`airflow-init`) that migrates the metadata
database and creates the admin user. This takes about 30–60 seconds.

```bash
docker compose ps
```

All services should show `healthy` or `running`.
`dbt-airflow-init` showing `exited (0)` is correct — it exits after finishing.

### 3. Services

| Service       | URL / connection                    | Credentials                 |
|---------------|-------------------------------------|-----------------------------|
| dbt           | `docker compose exec dbt dbt <cmd>` | —                           |
| Airflow UI    | http://localhost:8080                | airflow / airflow           |
| pgAdmin       | http://localhost:5051                | admin@example.com / admin   |
| retail-db     | host `localhost`, port `5434`       | retail_user / retail_pass   |
| airflow-db    | host `localhost`, port `5435`       | airflow / airflow           |

### 4. Connect pgAdmin to retail-db

pgAdmin runs inside Docker and connects to other containers by **service name**, not `localhost`.

In pgAdmin → Object → Register → Server:

- **General tab → Name**: `retail-db`
- **Connection tab**:
  - **Host name / address**: `retail-db`  ← Docker service name
  - **Port**: `5432`                       ← internal port (not 5434)
  - **Maintenance database**: `retail_db`
  - **Username**: `retail_user`
  - **Password**: `retail_pass`

> If you connect from your own machine (psql, DBeaver, DataGrip), use `localhost:5434`.

---

## 📊 Data model

### Source data (seeds)

The CSV files in `dbt_project/seeds/` simulate a production OLTP database:

```
raw_customers   ← customer master (name, city, segment, updated_at)
raw_products    ← product catalogue (name, category, brand, unit_price)
raw_stores      ← store locations
raw_orders      ← order headers (customer_id, store_id, payment_method, date)
raw_order_items ← order lines   (order_id, product_id, quantity, unit_price)
```

Seeds land in the `public_raw` schema (dbt appends the `raw` prefix to the default schema `public`).

### Medallion architecture

This project follows a three-layer Medallion pattern:

![Medallion Architecture](https://www.databricks.com/sites/default/files/inline-images/building-data-pipelines-with-delta-lake-120823.png)

*Source: Databricks*

```
Bronze   seeds/           raw_*         (public_raw schema — loaded by dbt seed)
         ↓
Silver   models/staging/  stg_*         (TABLE — cleaned, typed, stable source of truth)
         ↓
Silver+  models/intermediate/ int_*     (VIEW  — joins and lightweight transforms)
         ↓
Gold     models/marts/    dim_*, fact_* (TABLE — final analytical output)
```

### Data flow
```
raw_customers   → stg_customers   → dim_customer
raw_products    → stg_products    → dim_product
raw_stores      (store_id carried as FK in fact_sales)

raw_orders      → stg_orders       ──┐
                                     ├──► int_order_lines ──► fact_sales
raw_order_items → stg_order_items  ──┘

fact_sales references: dim_customer, dim_product (FK)
```
Grain of `fact_sales`: **one row per order line item**.

---

## 📁 Project structure

```
dbt_project/
├── seeds/                      raw CSVs → public_raw schema
├── models/
│   ├── staging/                Silver — clean + rename raw tables (TABLE)
│   │   ├── schema.yml
│   │   └── stg_*.sql
│   ├── intermediate/           Silver+ — joins and transforms (VIEW)
│   │   ├── schema.yml
│   │   └── int_*.sql
│   └── marts/                  Gold — dimensions and facts (TABLE)
│       ├── schema.yml
│       ├── dim_*.sql
│       └── fact_sales.sql
├── snapshots/                  SCD Type 2 history
├── tests/                      custom singular tests
├── selectors.yml               named model selectors
├── profiles.yml                database connection
└── dbt_project.yml             project settings (default: table)
```

---

## ⚙️ Model configuration with `{{ config() }}`

Every dbt model inherits its materialization from `dbt_project.yml`. The default here is `table`. You can override it per model using a `{{ config() }}` block at the top of the SQL file:

```sql
{{ config(materialized='view') }}
```

Open `models/intermediate/int_order_lines.sql` — it uses this to override the default and stay as a view. `fact_sales.sql` uses `{{ config(materialized='table') }}` to make the override explicit even though it matches the default.

### What else can go in `{{ config() }}`?

| Option | Example | What it does |
|---|---|---|
| `materialized` | `'table'`, `'view'`, `'incremental'`, `'ephemeral'` | How the model is stored |
| `schema` | `'intermediate'` | Write to a different schema |
| `alias` | `'order_lines'` | Rename the output table/view |
| `tags` | `['nightly', 'finance']` | Group models for selection |
| `pre_hook` | `"SET work_mem='256MB'"` | SQL to run before this model builds |
| `post_hook` | `"GRANT SELECT ON {{ this }} TO reporter"` | SQL to run after build |
| `grants` | `{'select': ['reporter']}` | Declarative permission grants |

Full reference: https://docs.getdbt.com/reference/model-configs

---

## 🧪 Step-by-step exercises

Work through the steps in order — each one builds on the previous.

---

### Step 1 — Explore the seed data

Open `dbt_project/seeds/` and read the five CSV files. Answer these questions:

- What is the natural key of each table?
- Which columns need to be cast to a different type?
- Which column in `raw_customers` drives SCD2 history tracking?

---

### Step 2 — Load seeds into the database

```bash
docker compose exec dbt dbt seed
```

In pgAdmin, expand `retail_db → Schemas → public_raw → Tables`.
You should see five tables: `raw_customers`, `raw_products`, `raw_stores`, `raw_orders`, `raw_order_items`.

---

### Step 3 — Write staging models

Open `dbt_project/models/staging/`. Each file has `TODO` comments.

Complete them in this order:

1. **`stg_customers.sql`** — cast `updated_at` to date
2. **`stg_products.sql`** — columns pass through
3. **`stg_orders.sql`** — cast `order_date` to date
4. **`stg_order_items.sql`** — add `line_total = quantity * unit_price`

```bash
docker compose exec dbt dbt run --selector staging_models
docker compose exec dbt dbt test --selector staging_models
```

---

### Step 4 — Explore the intermediate layer

Open `dbt_project/models/intermediate/int_order_lines.sql`.

This model:
- Joins `stg_orders` and `stg_order_items` into a single enriched row per order line
- Uses `{{ config(materialized='view') }}` to override the project default

Run it:

```bash
docker compose exec dbt dbt run --selector intermediate_models
```

In pgAdmin, verify that `int_order_lines` appears as a **VIEW** (not a table) under `public → Views`.

---

### Step 5 — Write mart models

Open `dbt_project/models/marts/`.

1. **`dim_product.sql`** — passthrough from `stg_products`
2. **`dim_customer.sql`** — `ROW_NUMBER()` to pick latest record per customer
3. **`fact_sales.sql`** — selects from `int_order_lines` (join already done)

```bash
docker compose exec dbt dbt run --selector mart_models
```

---

### Step 6 — Run data quality tests 🔍

```bash
docker compose exec dbt dbt test
```

Tests are defined in three `schema.yml` files (staging, intermediate, marts) and cover `not_null`, `unique`, `relationships`, and `accepted_values`.

A custom singular test in `tests/check_pos_total_sales.sql` ensures no `line_total` is zero or negative.

---

### Step 7 — Understand selectors

Open `dbt_project/selectors.yml`. Four selectors are defined:
`staging_models`, `intermediate_models`, `mart_models`, `all_models`.

```bash
docker compose exec dbt dbt run --selector all_models
```

---

### Step 8 — Take a snapshot (SCD Type 2) 📸

```bash
docker compose exec dbt dbt snapshot
```

In pgAdmin, expand `retail_db → Schemas → snapshots → Tables → dim_customer_snapshot`.
You should see **8 rows**, all with `dbt_valid_to = NULL` (all currently active).

---

## 🌀 Orchestrating with Airflow

The same steps you ran manually are wired up as a single DAG in Airflow.

Open the Airflow UI: **http://localhost:8080** (airflow / airflow)

The DAG `dbt_pipeline` runs these tasks in order:

| Task | Command |
|---|---|
| `dbt_seed` | `dbt seed` |
| `dbt_run_staging` | `dbt run --selector staging_models` |
| `dbt_run_marts` | `dbt run --selector mart_models` |
| `dbt_test` | `dbt test` |
| `dbt_snapshot` | `dbt snapshot` |

**Trigger it:**
1. Find `dbt_pipeline` in the DAG list
2. Toggle it on (switch on the left)
3. Click **▶ Trigger DAG**
4. Click the run → watch tasks go green left to right
5. Click any task → **Log** to see the dbt output

**Schedule**

The DAG is set to `schedule=None` — manual only. To run on a schedule, change one line in `dags/dbt_pipeline.py`:

```python
schedule="@daily"        # every day at midnight
schedule="0 6 * * 1"     # every Monday at 6am
schedule="0 * * * *"     # every hour
```

---

## 📖 Appendix: SCD Type 2 — tracking customer changes

The file `data/raw_customers_update.csv` contains two changes from the original seed:

| customer_id | Name  | What changed             | updated_at  |
|-------------|-------|--------------------------|-------------|
| 1           | Alice | segment: Regular → **VIP** | 2024-06-01 |
| 4           | David | city: Pärnu → **Tartu**    | 2024-06-01 |

### A. Apply the update

```bash
cp data/raw_customers_update.csv dbt_project/seeds/raw_customers.csv
```

### B. Re-seed, refresh staging, and re-snapshot

```bash
docker compose exec dbt dbt seed --full-refresh
docker compose exec dbt dbt run --selector staging_models
docker compose exec dbt dbt snapshot
```

### C. Query the snapshot history

```sql
SELECT customer_id, first_name, city, segment, dbt_valid_from, dbt_valid_to
FROM snapshots.dim_customer_snapshot
WHERE customer_id IN (1, 4)
ORDER BY customer_id, dbt_valid_from;
```

Expected result:

```
 customer_id | first_name | city    | segment | dbt_valid_from | dbt_valid_to
-------------+------------+---------+---------+----------------+--------------
 1           | Alice      | Tallinn | Regular | 2024-01-10     | 2024-06-01
 1           | Alice      | Tallinn | VIP     | 2024-06-01     | NULL
 4           | David      | Pärnu   | Premium | 2024-02-14     | 2024-06-01
 4           | David      | Tartu   | Premium | 2024-06-01     | NULL
```

- `dbt_valid_to = NULL` → current record
- `dbt_valid_to = <date>` → historical (closed) record

### D. Re-trigger the Airflow DAG

Re-trigger `dbt_pipeline` from the Airflow UI to run the full pipeline again with the updated data.

---

## 🛑 Stopping the stack

```bash
docker compose down
```

To remove all database data and start fresh:

```bash
docker compose down -v
rm -rf pgdata_retail pgdata_airflow logs
```
