"""STUB -- Order submitter (the sensor half of the assignment).

Waits for an order JSON file written by the price analyzer, then "submits" the
order by inserting it into the order_book table in prices-db.

    wait_for_order_file -> read_order -> submit_order -> log_submission

There is no external API in this exercise: order_book *is* the downstream
system. Submitting an order means writing a row to it.

Run it with:
    docker compose exec airflow-scheduler airflow dags test order_submitter

The sensor blocks until a file appears, so make sure the analyzer DAG has
written at least one order_*.json first. To create one by hand for testing:

    cat > data/orders/order_test.json <<'JSON'
    {"orderType": "Buy", "currentPrice": 84000.0, "rollingAveragePrice": 83500.0}
    JSON
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
    # TODO: add retries=3 and retry_delay=timedelta(seconds=5).
    # Note what you are NOT writing: no loop, no time.sleep, no attempt
    # counter. Airflow owns retry behaviour -- a task that raises is retried
    # according to this configuration.
}


def read_order(**context):
    """Pick up the oldest unprocessed order file and return its contents.

    TODO: glob DATA_DIR for order_*.json, take the oldest, json.load it, and
    return {"order": <parsed json>, "path": <file path>}.

    The sensor only guarantees that *some* file matched -- choosing which one
    is this task's job.
    """
    raise NotImplementedError


def submit_order(**context):
    """Insert the order into order_book.

    TODO: xcom_pull the payload from "read_order" and INSERT into order_book
    (order_type, price, rolling_avg, source_file).

    source_file has a UNIQUE constraint, so submitting the same file twice
    raises an error. Make the insert idempotent instead:

        INSERT INTO order_book (...) VALUES (...)
        ON CONFLICT (source_file) DO NOTHING
        RETURNING id

    RETURNING gives back the new id, or nothing at all when the row already
    existed -- use that to tell a fresh submission from a duplicate. Return a
    dict describing which happened.
    """
    raise NotImplementedError


def log_submission(**context):
    """Record the outcome in orders_log and move the processed file aside.

    TODO: insert payload / response / status into orders_log, then rename the
    file (e.g. to <path>.done).

    Renaming matters: leave the file in place and the sensor fires on it again
    on the next run, resubmitting the same order forever.
    """
    raise NotImplementedError


with DAG(
    dag_id="order_submitter",
    description="STUB -- watch for order files and submit them to order_book",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    # No schedule: the sensor drives this DAG.
    schedule=None,
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["practice", "btc", "sensor", "stub"],
) as dag:

    # TODO: add mode="reschedule" so the sensor releases its worker slot
    # between checks instead of holding one for the whole timeout. With the
    # default "poke" mode a long-waiting sensor occupies a slot doing nothing.
    #
    # fs_conn_id points at an Airflow connection of type "File (path)".
    # airflow-init creates fs_default for you; a sensor pointed at a connection
    # that does not exist just retries, so the DAG looks like it is hanging.
    wait_for_order_file = FileSensor(
        task_id="wait_for_order_file",
        fs_conn_id="fs_default",
        filepath=f"{DATA_DIR}/order_*.json",
        poke_interval=30,
        timeout=600,
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
