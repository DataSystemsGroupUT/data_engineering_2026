# Teaching companion — solution snippets

Code for each task, in the order students meet it. Full files live in
`solution/`; this is the side-by-side version for the projector.

**Jump to:** [Setup](#setup) · [Task 1](#task-1--single-dag) ·
[Task 2](#task-2--decomposition) · [Task 3](#task-3--order-trigger) ·
[Gotchas](#gotchas) · [Live demo](#live-demo-cheatsheet)

---

## Setup

```bash
docker compose up -d                      # everything; init runs automatically
docker compose logs -f airflow-init       # watch first-time setup
```

UI at <http://localhost:8080>, `airflow` / `airflow`.

`airflow-init` waits for both databases to be healthy, then migrates the
metadata DB, creates the admin user, and registers two connections:
`prices_db` (Postgres) and `fs_default` (filesystem, for the sensor).

Tables are created automatically — `solution/create_tables.sql` is mounted into
the `prices-db` init directory:

| Table | Written by | Holds |
| --- | --- | --- |
| `btc_prices` | Task 1 / 2 | every fetched price |
| `btc_rolling_avg` | Task 1 / 2 | 15-min average per run |
| `orders_log` | Task 1 / 2 / 3 | audit trail of every signal and submission |
| `order_book` | Task 3 | submitted orders (the "downstream system") |

---

## Task 1 — single DAG

Everything in one `PythonOperator`. The point is to get a working pipeline, not
a well-factored one — Task 2 fixes that.

### Fetch and store

```python
def fetch_and_store_price(**context):
    ts = context["logical_date"]
    pg = PostgresHook(postgres_conn_id=CONN_ID)

    response = requests.get(PRICE_API, timeout=10)
    response.raise_for_status()
    price = float(response.json()["price"])

    pg.run(
        "INSERT INTO btc_prices (ts, price) VALUES (%s, %s)",
        parameters=(ts, price),
    )
```

> `raise_for_status()` turns an HTTP 429/451 into a retryable exception. Without
> it you get a `KeyError` on the missing `"price"` field — a much more confusing
> failure for a student to debug.

### Rolling average

```python
    cutoff = ts - timedelta(minutes=ROLLING_WINDOW_MINUTES)
    row = pg.get_first(
        "SELECT AVG(price) FROM btc_prices WHERE ts >= %s AND ts <= %s",
        parameters=(cutoff, ts),
    )
    rolling_avg = float(row[0])

    pg.run(
        "INSERT INTO btc_rolling_avg (ts, rolling_avg) VALUES (%s, %s)",
        parameters=(ts, rolling_avg),
    )
```

> Bounded at **both** ends. `>= cutoff` alone means re-running an old interval
> picks up rows newer than the run itself — the pipeline stops being
> reproducible. Good place to ask *why does the upper bound matter?*

### Decide

```python
    rows = pg.get_records("SELECT price FROM btc_prices ORDER BY ts DESC LIMIT 4")

    order = None
    if len(rows) >= 4:
        prices = [float(r[0]) for r in reversed(rows)]
        previous, current = prices[:-1], prices[-1]

        if all(p < rolling_avg for p in previous) and current > rolling_avg:
            order_type = "Buy"
        elif all(p > rolling_avg for p in previous) and current < rolling_avg:
            order_type = "Sell"
        else:
            order_type = None

        if order_type:
            order = {
                "orderType": order_type,
                "currentPrice": current,
                "rollingAveragePrice": rolling_avg,
            }
```

> **The rule is a _crossing_, not a level test.** Buy when price rises *through*
> the average after sitting below it. A plain "price < average → buy" fires on
> every single run and floods `data/orders/`.
>
> Three prior points on one side is a noise filter — one jittery tick shouldn't
> trigger a trade.

### Record

```python
    if order:
        os.makedirs(DATA_DIR, exist_ok=True)
        filename = os.path.join(DATA_DIR, f"order_{ts.strftime('%Y%m%dT%H%M%S')}.json")
        with open(filename, "w") as f:
            json.dump(order, f)

        pg.run(
            "INSERT INTO orders_log (payload, response, status) VALUES (%s, %s, %s)",
            parameters=(json.dumps(order), None, "created"),
        )
```

### DAG block

```python
with DAG(
    dag_id="price_trend_analyzer",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule="*/1 * * * *",
    catchup=False,
    max_active_runs=1,
    default_args={"owner": "airflow", "retries": 2,
                  "retry_delay": timedelta(seconds=30)},
) as dag:

    PythonOperator(
        task_id="fetch_and_store_price",
        python_callable=fetch_and_store_price,
    )
```

> `catchup=False` + `max_active_runs=1` — without them, a DAG with a past
> `start_date` and a 1-minute schedule immediately backfills thousands of runs.

---

## Task 2 — decomposition

Same pipeline, five tasks. Stub ships as `EmptyOperator` placeholders so the DAG
is green before any logic exists; students swap them left to right.

```
fetch_price → store_price → compute_rolling_average → decide_order → record_order
```

### 1. fetch_price

```python
def fetch_price(**context):
    response = requests.get(PRICE_API, timeout=10)
    response.raise_for_status()
    price = float(response.json()["price"])
    ts = context["logical_date"]

    return {"price": price, "ts": ts.isoformat()}
```

> `.isoformat()` — XCom serializes to JSON and a `datetime` does not round-trip
> cleanly. Downstream does `pendulum.parse(...)` to get it back.

### 2. store_price

```python
def store_price(**context):
    payload = context["ti"].xcom_pull(task_ids="fetch_price")
    price, ts = payload["price"], payload["ts"]

    PostgresHook(postgres_conn_id=CONN_ID).run(
        "INSERT INTO btc_prices (ts, price) VALUES (%s, %s)",
        parameters=(ts, price),
    )
```

### 3. compute_rolling_average

```python
def compute_rolling_average(**context):
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
    return rolling_avg
```

### 4. decide_order

```python
def decide_order(**context):
    ti = context["ti"]
    rolling_avg = float(ti.xcom_pull(task_ids="compute_rolling_average"))

    pg = PostgresHook(postgres_conn_id=CONN_ID)
    rows = pg.get_records("SELECT price FROM btc_prices ORDER BY ts DESC LIMIT 4")

    if len(rows) < 4:
        return None                      # normal on the first few runs

    prices = [float(r[0]) for r in reversed(rows)]
    previous, current = prices[:-1], prices[-1]

    if all(p < rolling_avg for p in previous) and current > rolling_avg:
        order_type = "Buy"
    elif all(p > rolling_avg for p in previous) and current < rolling_avg:
        order_type = "Sell"
    else:
        return None

    return {"orderType": order_type,
            "currentPrice": current,
            "rollingAveragePrice": rolling_avg}
```

> Returning `None` when history is short is deliberate — "not enough data yet"
> is the expected state, not a failure. Raising would turn the first three runs
> red for no reason.

### 5. record_order

```python
def record_order(**context):
    ti = context["ti"]
    order = ti.xcom_pull(task_ids="decide_order")

    if not order:
        return                           # no signal this run

    ts = pendulum.parse(ti.xcom_pull(task_ids="fetch_price")["ts"])
    os.makedirs(DATA_DIR, exist_ok=True)
    filename = os.path.join(DATA_DIR, f"order_{ts.strftime('%Y%m%dT%H%M%S')}.json")
    with open(filename, "w") as f:
        json.dump(order, f)

    PostgresHook(postgres_conn_id=CONN_ID).run(
        "INSERT INTO orders_log (payload, response, status) VALUES (%s, %s, %s)",
        parameters=(json.dumps(order), None, "created"),
    )
```

### Wiring

```python
    t_fetch = PythonOperator(
        task_id="fetch_price",
        python_callable=fetch_price,
        retries=3,                       # only this task touches the network
    )
    t_store   = PythonOperator(task_id="store_price",  python_callable=store_price)
    t_rolling = PythonOperator(task_id="compute_rolling_average",
                               python_callable=compute_rolling_average)
    t_decide  = PythonOperator(task_id="decide_order", python_callable=decide_order)
    t_record  = PythonOperator(task_id="record_order", python_callable=record_order)

    t_fetch >> t_store >> t_rolling >> t_decide >> t_record
```

> **The payoff line.** `retries=3` on `fetch_price` only. In the monolith, a
> transient API error re-runs the database writes too. This is the concrete
> answer to "what does splitting buy you?"

### Are XComs mandatory here?

No — worth raising if there's time. Three alternatives:

1. **Re-read from Postgres.** `store_price` just wrote the row;
   `compute_rolling_average` could `SELECT ... ORDER BY ts DESC LIMIT 1`. Costs
   reproducibility — `logical_date` no longer anchors the run.
2. **Templated `op_kwargs`** with `{{ ti.xcom_pull(...) }}`. Same XCom, but the
   callables become plain functions taking normal arguments — unit-testable
   without an Airflow context.
3. **Nothing at all.** `logical_date` is in *every* task's context, so
   `compute_rolling_average` needn't pull the timestamp from XCom at all.

Honest framing: XCom is for small values that don't belong in your data store. A
price and a timestamp qualify. The rolling average arguably doesn't — it's
written to `btc_rolling_avg` one line earlier.

---

## Task 3 — order trigger

Sensor waits for an order file, then submits it to `order_book`. No external
API: **the table is the downstream system.**

```
wait_for_order_file → read_order → submit_order → log_submission
```

### Sensor

```python
    wait_for_order_file = FileSensor(
        task_id="wait_for_order_file",
        fs_conn_id="fs_default",
        filepath=f"{DATA_DIR}/order_*.json",
        poke_interval=30,
        timeout=600,
        mode="reschedule",               # release the worker slot between pokes
    )
```

> `mode="reschedule"` vs default `"poke"`: poke holds a worker slot for the
> whole 10-minute timeout doing nothing. With one slot and two sensors you
> deadlock.
>
> `fs_default` exists because `airflow-init` creates it — it normally ships with
> Airflow's *example* connections, which we disable. A sensor pointed at a
> missing connection just retries, so **the DAG looks like it's hanging** rather
> than failing. Good debugging story.

### read_order

```python
def read_order(**context):
    files = sorted(glob.glob(os.path.join(DATA_DIR, "order_*.json")))
    if not files:
        raise FileNotFoundError(f"No order files found in {DATA_DIR}")

    path = files[0]                      # oldest first
    with open(path) as f:
        order = json.load(f)

    return {"order": order, "path": path}
```

> The sensor reports that *a* file matched, not which one. Picking is this
> task's job.

### submit_order

```python
def submit_order(**context):
    payload = context["ti"].xcom_pull(task_ids="read_order")
    order, path = payload["order"], payload["path"]

    pg = PostgresHook(postgres_conn_id=CONN_ID)
    row = pg.get_first(
        """
        INSERT INTO order_book (order_type, price, rolling_avg, source_file)
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (source_file) DO NOTHING
        RETURNING id
        """,
        parameters=(order["orderType"], order["currentPrice"],
                    order["rollingAveragePrice"], os.path.basename(path)),
    )

    if row is None:
        return {"status": "duplicate", "order_book_id": None}
    return {"status": "success", "order_book_id": row[0]}
```

> `source_file` is `UNIQUE`. `ON CONFLICT DO NOTHING ... RETURNING id` makes a
> re-run idempotent: `RETURNING` gives back the id on a fresh insert and
> **nothing at all** when the row already existed. That's how you tell the two
> apart without raising.

### log_submission

```python
def log_submission(**context):
    ti = context["ti"]
    payload = ti.xcom_pull(task_ids="read_order")
    result = ti.xcom_pull(task_ids="submit_order")
    order, path = payload["order"], payload["path"]

    PostgresHook(postgres_conn_id=CONN_ID).run(
        "INSERT INTO orders_log (payload, response, status) VALUES (%s, %s, %s)",
        parameters=(json.dumps(order), json.dumps(result), result["status"]),
    )

    os.rename(path, path + ".done")      # stop the sensor re-matching it
```

### Retries

```python
default_args = {
    "owner": "airflow",
    "retries": 3,
    "retry_delay": timedelta(seconds=5),
}
```

> Note what is **not** here: no loop, no `time.sleep`, no attempt counter.
> Airflow owns retry behaviour. A task that raises is retried per this config.
> The original version of this exercise had students hand-roll it.

### Why rename rather than delete?

Two mechanisms, two different failures — worth being precise:

- **The rename** stops the resubmission loop. The sensor globs `order_*.json`;
  `.json.done` no longer matches. Leave the name alone and the sensor fires on
  it forever.
- **The UNIQUE constraint** is the backstop. Without the rename you'd still get
  a `duplicate` row in `orders_log` every single run — a green DAG quietly
  logging garbage.

`.done` rather than `os.remove` keeps the audit trail of what the analyzer
actually emitted.

---

## Gotchas

| Symptom | Cause |
| --- | --- |
| `dependency failed to start: prices-db is unhealthy` | Corrupt `pgdata_*` from an interrupted `initdb`. `docker compose down && rm -rf pgdata_airflow pgdata_prices && docker compose up -d` |
| `image ... does not match the specified platform` | `DOCKER_DEFAULT_PLATFORM=linux/amd64` in the shell. `unset` it — compose pins no architecture on purpose |
| Sensor DAG hangs, no logs | `fs_default` missing. Check `airflow connections get fs_default` |
| `TypeError: 'NoneType' object is not subscriptable` | `airflow tasks test` on a single task that needs upstream XCom. Expected — use `dags test` for the chain |
| DAG missing from UI | `docker compose logs airflow-scheduler` for an import error; ~30s to pick up new files |
| Thousands of queued runs | `catchup=True` with a past `start_date` |

---

## Live demo cheatsheet

```bash
# whole chain, real prices
docker compose exec airflow-scheduler airflow dags test price_trend_analyzer_tasks

# one task (fetch_price only — others need upstream XCom)
docker compose exec airflow-scheduler \
  airflow tasks test price_trend_analyzer_tasks fetch_price 2026-01-01

# what landed
docker compose exec prices-db psql -U prices_user -d prices_db \
  -c "SELECT count(*) FROM btc_prices;" \
  -c "SELECT * FROM orders_log ORDER BY id DESC LIMIT 5;" \
  -c "SELECT * FROM order_book;"
```

**Forcing a Buy signal.** Signals are rare, so seed a crossing. The window is
7 seeded rows + the live price; the three most recent must sit *below* the
average while the live price lands *above* it:

```sql
TRUNCATE btc_prices, btc_rolling_avg, orders_log, order_book RESTART IDENTITY;
INSERT INTO btc_prices (ts, price) VALUES
  (now() - interval '10 min', 93394.70),
  (now() - interval '9 min',  93394.70),
  (now() - interval '8 min',  93394.70),
  (now() - interval '7 min',  93394.70),
  (now() - interval '3 min',  70000),
  (now() - interval '2 min',  70000),
  (now() - interval '1 min',  70000);
```

Then run the DAG — `decide_order` logs `Signal: {'orderType': 'Buy', ...}`.
Tune the high value if BTC has moved far from ~84k: the average of all eight
values must land just *under* the live price.

**Then demo the sensor:**

```bash
docker compose exec airflow-scheduler airflow dags test order_submitter   # success
rm -f data/orders/*.done                                                  # replay it
docker compose exec airflow-scheduler airflow dags test order_submitter   # duplicate
```

`order_book` still holds one row; `orders_log` holds two — one `success`, one
`duplicate`. That's the idempotency lesson in ten seconds.
