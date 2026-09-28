"""STUB -- BTC price analyzer as a single task.

Fill in the TODOs. The whole pipeline lives in one PythonOperator here; the
decomposition exercise (price_trend_analyzer_tasks.py) then asks you to split it.

Run it with:
    docker compose exec airflow-scheduler \
      airflow tasks test price_trend_analyzer fetch_and_store_price 2026-01-01

Tables available in prices-db (created for you): btc_prices, btc_rolling_avg,
orders_log, order_book. Connection id: "prices_db".
"""

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
import json
import os
import pendulum
import requests
from datetime import timedelta

DATA_DIR = "/tmp/data/orders"
PRICE_API = "https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT"
CONN_ID = "prices_db"
ROLLING_WINDOW_MINUTES = 15

default_args = {
    "owner": "airflow",
    "retries": 2,
    "retry_delay": timedelta(seconds=30),
}


def fetch_and_store_price(**context):
    """Fetch the BTC price, store it, average it, and decide whether to order."""
    ts = context["logical_date"]
    pg = PostgresHook(postgres_conn_id=CONN_ID)

    # ------------------------------------------------------------------
    # TODO 1 -- Fetch the current BTC price.
    #   GET PRICE_API, raise on a bad HTTP status, and read the "price" field.
    #   Hint: requests.get(..., timeout=10) and response.raise_for_status()
    # ------------------------------------------------------------------
    price = None

    # ------------------------------------------------------------------
    # TODO 2 -- Insert (ts, price) into btc_prices.
    #   Hint: pg.run("INSERT INTO ... VALUES (%s, %s)", parameters=(ts, price))
    # ------------------------------------------------------------------

    # ------------------------------------------------------------------
    # TODO 3 -- Compute the rolling average over the last
    #   ROLLING_WINDOW_MINUTES, and insert it into btc_rolling_avg.
    #   Hint: pg.get_first("SELECT AVG(price) FROM btc_prices WHERE ts >= %s ...")
    #   Bound the window at both ends so a re-run cannot read future rows.
    # ------------------------------------------------------------------
    rolling_avg = None

    # ------------------------------------------------------------------
    # TODO 4 -- Decide whether to place an order.
    #   Read the last 4 prices (newest first) from btc_prices.
    #   A signal fires when the 3 older prices sit on one side of rolling_avg
    #   and the newest price has crossed to the other side:
    #       Buy  -- the 3 were below the average, the newest is above it
    #       Sell -- the 3 were above the average, the newest is below it
    #   Set `order` to a dict with keys orderType / currentPrice /
    #   rollingAveragePrice, or leave it None when there is no signal.
    # ------------------------------------------------------------------
    order = None

    # ------------------------------------------------------------------
    # TODO 5 -- If an order fired, write it as JSON into DATA_DIR and insert a
    #   row into orders_log with status "created".
    #   The JSON file is what the order_submitter DAG's FileSensor waits for,
    #   so name it order_<timestamp>.json.
    # ------------------------------------------------------------------
    if order:
        pass


with DAG(
    dag_id="price_trend_analyzer",
    description="STUB -- BTC price analyzer in a single task",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule="*/1 * * * *",
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["practice", "btc", "stub"],
) as dag:

    fetch_task = PythonOperator(
        task_id="fetch_and_store_price",
        python_callable=fetch_and_store_price,
    )
