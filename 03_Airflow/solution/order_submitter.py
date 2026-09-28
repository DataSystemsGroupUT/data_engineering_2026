"""Order submitter -- the sensor half of the assignment (reference solution).

Waits for an order JSON file written by the price analyzer DAG, then "submits"
the order by inserting it into the order_book table in prices-db, and logs the
outcome to orders_log.

    wait_for_order_file -> read_order -> submit_order -> log_submission

There is no external API here: order_book *is* the downstream system. Submitting
means writing a row, and the UNIQUE constraint on source_file is what makes a
repeat submission of the same file fail loudly instead of silently duplicating.

The FileSensor uses mode="reschedule" so it releases its worker slot between
checks instead of holding one for the whole timeout.
"""

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.sensors.filesystem import FileSensor
import glob
import json
import os
import pendulum
from datetime import timedelta

DATA_DIR = "/tmp/data/orders"
CONN_ID = "prices_db"

default_args = {
    "owner": "airflow",
    # The submission step can fail on a transient database problem, so every
    # task retries a few times before the run is marked failed.
    "retries": 3,
    "retry_delay": timedelta(seconds=5),
}


def read_order(**context):
    """Pick up the oldest unprocessed order file and return its contents.

    The sensor only tells us *a* file exists, not which one, so the first real
    task is to choose one. Oldest-first keeps processing in the order the
    analyzer produced the signals.
    """
    files = sorted(glob.glob(os.path.join(DATA_DIR, "order_*.json")))
    if not files:
        # The sensor passed but the file is gone -- possible if a previous run
        # processed it. Nothing to do.
        raise FileNotFoundError(f"No order files found in {DATA_DIR}")

    path = files[0]
    with open(path) as f:
        order = json.load(f)

    print(f"Read order from {path}: {order}")
    return {"order": order, "path": path}


def submit_order(**context):
    """Insert the order into order_book -- the 'submission' step.

    ON CONFLICT DO NOTHING makes this idempotent: re-running the task for a file
    that was already submitted is a no-op rather than an error. The RETURNING
    clause tells us which happened.
    """
    ti = context["ti"]
    payload = ti.xcom_pull(task_ids="read_order")
    order, path = payload["order"], payload["path"]

    pg = PostgresHook(postgres_conn_id=CONN_ID)
    row = pg.get_first(
        """
        INSERT INTO order_book (order_type, price, rolling_avg, source_file)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (source_file) DO NOTHING
        RETURNING id
        """,
        parameters=(
            order["orderType"],
            order["currentPrice"],
            order["rollingAveragePrice"],
            os.path.basename(path),
        ),
    )

    if row is None:
        # Already in the order book -- a duplicate submission, not a failure.
        print(f"Order from {path} was already submitted; skipping.")
        return {"status": "duplicate", "order_book_id": None}

    print(f"Submitted order from {path} as order_book id={row[0]}")
    return {"status": "success", "order_book_id": row[0]}


def log_submission(**context):
    """Record the outcome in orders_log, then move the file out of the way.

    Renaming the processed file is what stops the sensor from firing on it
    again on the next run.
    """
    ti = context["ti"]
    payload = ti.xcom_pull(task_ids="read_order")
    result = ti.xcom_pull(task_ids="submit_order")
    order, path = payload["order"], payload["path"]

    pg = PostgresHook(postgres_conn_id=CONN_ID)
    pg.run(
        "INSERT INTO orders_log (payload, response, status) VALUES (%s, %s, %s)",
        parameters=(json.dumps(order), json.dumps(result), result["status"]),
    )

    processed = path + ".done"
    os.rename(path, processed)
    print(f"Logged '{result['status']}' and moved file to {processed}")


with DAG(
    dag_id="order_submitter",
    description="Watch for order files and submit them to the order_book table",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    # No schedule: the sensor drives this DAG. Trigger it manually, or set a
    # schedule so a fresh run is always waiting for the next order file.
    schedule=None,
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["practice", "btc", "sensor"],
) as dag:

    wait_for_order_file = FileSensor(
        task_id="wait_for_order_file",
        # fs_default points at / in the stock Airflow image, so an absolute
        # filepath works without configuring the connection.
        fs_conn_id="fs_default",
        filepath=f"{DATA_DIR}/order_*.json",
        poke_interval=30,
        timeout=600,
        # Release the worker slot between checks instead of blocking it.
        mode="reschedule",
    )

    t_read = PythonOperator(
        task_id="read_order",
        python_callable=read_order,
    )

    t_submit = PythonOperator(
        task_id="submit_order",
        python_callable=submit_order,
    )

    t_log = PythonOperator(
        task_id="log_submission",
        python_callable=log_submission,
    )

    wait_for_order_file >> t_read >> t_submit >> t_log
