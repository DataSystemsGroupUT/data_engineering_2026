"""BTC price analyzer -- one task per step.

Same pipeline as price_trend_analyzer.py, but split into five PythonOperators
so the DAG graph in the Airflow UI shows the actual data flow:

    fetch_price -> store_price -> compute_rolling_average -> decide_order -> record_order

Splitting buys three things the single-task version cannot offer:

  * Granular retries. Only the network call is flaky, so only fetch_price
    retries. In the monolith a transient API error re-runs the DB writes too.
  * A readable graph and per-task logs, so a failure points at one step.
  * Independently testable steps:
        airflow tasks test price_trend_analyzer_tasks compute_rolling_average <date>

Steps hand values to each other through XCom -- Airflow's small-payload
message passing. Returning a value pushes it; ti.xcom_pull() reads it back.
XCom is for metadata-sized values (here: a price and a timestamp), never for
datasets -- payloads are serialized into the metadata database.
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

# Applied to every task. Retries are what make a scheduled pipeline survive a
# transient failure without anyone watching it.
default_args = {
    "owner": "airflow",
    "retries": 2,
    "retry_delay": timedelta(seconds=30),
}


def fetch_price(**context):
    """Step 1 -- call the price API. The only task that touches the network."""
    response = requests.get(PRICE_API, timeout=10)
    # Turn an HTTP error status into an exception so Airflow retries the task,
    # instead of failing later with a confusing KeyError on the JSON body.
    response.raise_for_status()
    price = float(response.json()["price"])

    # logical_date is the scheduled slot this run represents. Using it instead
    # of "now" keeps a re-run of a past interval reproducible.
    ts = context["logical_date"]

    print(f"Fetched BTC price {price} for {ts.isoformat()}")
    # Returning a value pushes it to XCom under the key "return_value".
    return {"price": price, "ts": ts.isoformat()}


def store_price(**context):
    """Step 2 -- persist the fetched price."""
    ti = context["ti"]
    payload = ti.xcom_pull(task_ids="fetch_price")
    price, ts = payload["price"], payload["ts"]

    pg = PostgresHook(postgres_conn_id=CONN_ID)
    pg.run(
        "INSERT INTO btc_prices (ts, price) VALUES (%s, %s)",
        parameters=(ts, price),
    )
    print(f"Stored price {price} at {ts}")


def compute_rolling_average(**context):
    """Step 3 -- average the last ROLLING_WINDOW_MINUTES of prices."""
    ti = context["ti"]
    ts = pendulum.parse(ti.xcom_pull(task_ids="fetch_price")["ts"])
    cutoff = ts - timedelta(minutes=ROLLING_WINDOW_MINUTES)

    pg = PostgresHook(postgres_conn_id=CONN_ID)
    row = pg.get_first(
        "SELECT AVG(price) FROM btc_prices WHERE ts >= %s AND ts <= %s",
        parameters=(cutoff, ts),
    )
    rolling_avg = float(row[0])

    pg.run(
        "INSERT INTO btc_rolling_avg (ts, rolling_avg) VALUES (%s, %s)",
        parameters=(ts, rolling_avg),
    )
    print(f"Rolling average over {ROLLING_WINDOW_MINUTES} min: {rolling_avg}")
    return rolling_avg


def decide_order(**context):
    """Step 4 -- detect a crossing of the rolling average.

    A signal fires when the three prices before the current one sat on one side
    of the average and the current price has crossed to the other:

      BUY  -- price was below the average and has risen through it
      SELL -- price was above the average and has fallen through it

    Requiring three prior points on one side is a simple way to avoid reacting
    to a single noisy tick. Returns None when there is no signal.
    """
    ti = context["ti"]
    rolling_avg = float(ti.xcom_pull(task_ids="compute_rolling_average"))

    pg = PostgresHook(postgres_conn_id=CONN_ID)
    rows = pg.get_records("SELECT price FROM btc_prices ORDER BY ts DESC LIMIT 4")

    # Not enough history yet -- normal for the first few runs.
    if len(rows) < 4:
        print(f"Only {len(rows)} prices so far; need 4. No signal.")
        return None

    prices = [float(r[0]) for r in reversed(rows)]
    previous, current = prices[:-1], prices[-1]

    if all(p < rolling_avg for p in previous) and current > rolling_avg:
        order_type = "Buy"
    elif all(p > rolling_avg for p in previous) and current < rolling_avg:
        order_type = "Sell"
    else:
        print(f"No crossing: current={current}, rolling_avg={rolling_avg}")
        return None

    order = {
        "orderType": order_type,
        "currentPrice": current,
        "rollingAveragePrice": rolling_avg,
    }
    print(f"Signal: {order}")
    return order


def record_order(**context):
    """Step 5 -- write the order to disk and log it.

    The JSON file is what the FileSensor in the extension exercise waits for.
    """
    ti = context["ti"]
    order = ti.xcom_pull(task_ids="decide_order")

    # decide_order returns None on most runs; nothing to record.
    if not order:
        print("No order to record.")
        return

    ts = pendulum.parse(ti.xcom_pull(task_ids="fetch_price")["ts"])
    os.makedirs(DATA_DIR, exist_ok=True)
    filename = os.path.join(DATA_DIR, f"order_{ts.strftime('%Y%m%dT%H%M%S')}.json")
    with open(filename, "w") as f:
        json.dump(order, f)

    pg = PostgresHook(postgres_conn_id=CONN_ID)
    pg.run(
        "INSERT INTO orders_log (payload, response, status) VALUES (%s, %s, %s)",
        parameters=(json.dumps(order), None, "created"),
    )
    print(f"Recorded order at {filename}")


with DAG(
    dag_id="price_trend_analyzer_tasks",
    description="BTC price analyzer decomposed into one task per step",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule="*/1 * * * *",
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["practice", "btc"],
) as dag:

    t_fetch = PythonOperator(
        task_id="fetch_price",
        python_callable=fetch_price,
        # Only this task talks to the network, so it gets the extra retries.
        retries=3,
    )

    t_store = PythonOperator(
        task_id="store_price",
        python_callable=store_price,
    )

    t_rolling = PythonOperator(
        task_id="compute_rolling_average",
        python_callable=compute_rolling_average,
    )

    t_decide = PythonOperator(
        task_id="decide_order",
        python_callable=decide_order,
    )

    t_record = PythonOperator(
        task_id="record_order",
        python_callable=record_order,
    )

    # Each step needs the previous one's result, so the graph is a chain.
    t_fetch >> t_store >> t_rolling >> t_decide >> t_record
