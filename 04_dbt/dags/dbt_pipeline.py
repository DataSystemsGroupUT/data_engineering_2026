"""dbt_pipeline.py — Airflow DAG that orchestrates the full dbt project.

Pipeline shape:
    dbt_seed → dbt_run_staging → dbt_run_marts → dbt_test → dbt_snapshot

Each task runs a dbt CLI command via BashOperator.  dbt-core and dbt-postgres
are pre-installed in this Airflow image through _PIP_ADDITIONAL_REQUIREMENTS
in compose.yml.  The dbt project is mounted at /dbt.

Schedule: manual trigger only (schedule=None).  Run it from the Airflow UI or:

    docker compose exec airflow-scheduler \
        airflow dags trigger dbt_pipeline

Learning objectives for students
---------------------------------
1. Understand how Airflow wraps dbt commands into an orchestrated pipeline.
2. Observe how task dependencies (>>) enforce correct execution order.
3. Inspect XCom / task logs to see dbt output for each step.
4. (Extension) Add a sensor that waits for retail-db to be ready before seeding.
"""

from __future__ import annotations

import pendulum
from airflow import DAG
from airflow.operators.bash import BashOperator

DBT_PROJECT_DIR = "/dbt"
DBT_PROFILES_DIR = "/dbt"

# Common flags added to every dbt subcommand.
# In dbt 1.8+, --project-dir and --profiles-dir are subcommand flags
# (they follow the subcommand, not dbt itself).
DBT_FLAGS = (
    f"--no-use-colors "
    f"--project-dir {DBT_PROJECT_DIR} "
    f"--profiles-dir {DBT_PROFILES_DIR}"
)

default_args = {
    "owner": "airflow",
    "retries": 1,
}

with DAG(
    dag_id="dbt_pipeline",
    description="Seed raw data, build staging + mart models, run tests, take snapshot.",
    schedule=None,                          # trigger manually
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    default_args=default_args,
    tags=["dbt", "retail"],
) as dag:

    # ------------------------------------------------------------------
    # Step 1: Load transactional seed CSVs into the raw schema
    # ------------------------------------------------------------------
    dbt_seed = BashOperator(
        task_id="dbt_seed",
        bash_command=f"dbt seed {DBT_FLAGS}",
        doc_md="""
        Loads the CSV files from dbt_project/seeds/ into the `raw` schema
        of retail-db:
          - raw.raw_customers
          - raw.raw_products
          - raw.raw_stores
          - raw.raw_orders
          - raw.raw_order_items
        """,
    )

    # ------------------------------------------------------------------
    # Step 2: Build staging models
    # ------------------------------------------------------------------
    dbt_run_staging = BashOperator(
        task_id="dbt_run_staging",
        bash_command=f"dbt run --selector staging_models {DBT_FLAGS}",
        doc_md="""
        Runs only the staging layer models (selector: staging_models):
          - stg_customers, stg_products, stg_orders, stg_order_items
        These clean and rename the raw seed tables.
        """,
    )

    # ------------------------------------------------------------------
    # Step 3: Build mart models (dimensions and fact table)
    # ------------------------------------------------------------------
    dbt_run_marts = BashOperator(
        task_id="dbt_run_marts",
        bash_command=f"dbt run --selector mart_models {DBT_FLAGS}",
        doc_md="""
        Runs only the marts layer (selector: mart_models):
          - dim_customer, dim_product, fact_sales
        These join and aggregate the staging tables into a star schema.
        """,
    )

    # ------------------------------------------------------------------
    # Step 4: Run all schema + custom tests
    # ------------------------------------------------------------------
    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"dbt test {DBT_FLAGS}",
        doc_md="""
        Runs all tests defined in schema.yml (not_null, unique,
        relationships, accepted_values) plus the custom singular test
        in tests/check_pos_total_sales.sql.
        """,
    )

    # ------------------------------------------------------------------
    # Step 5: Take a snapshot of dim_customer for SCD2 tracking
    # ------------------------------------------------------------------
    dbt_snapshot = BashOperator(
        task_id="dbt_snapshot",
        bash_command=f"dbt snapshot {DBT_FLAGS}",
        doc_md="""
        Runs dim_customer_snapshot.  On first run it creates the snapshot
        table.  On subsequent runs (after updating raw_customers.csv) it
        appends a new row for changed customers and closes the old one.
        """,
    )

    # Define execution order
    dbt_seed >> dbt_run_staging >> dbt_run_marts >> dbt_test >> dbt_snapshot
