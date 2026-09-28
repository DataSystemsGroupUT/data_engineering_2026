# BTC Price Analyzer — Airflow Practice Assignment

## 🧭 Table of Contents

| Section                                           | Duration | Description                                         |
| ------------------------------------------------- | -------- | --------------------------------------------------- |
| 1. Introduction to Apache Airflow                 | 5 mins   | Overview of Airflow and its use in data engineering |
| 2. Discussion: When (and When Not) to Use Airflow | 10 mins  | Advanced discussion of Airflow pros & cons          |
| 3. Setting up Airflow Environment                 | 20 mins  | Step-by-step setup using Docker Compose             |
| 4. Assignment: BTC Price Analyzer DAG             | 1 hour   | Hands-on project with Postgres integration          |
| 5. Wrap-up and Q&A                                | 10 mins  | Summary and troubleshooting                         |

---

## 🚀 Introduction to Apache Airflow

[![Apache Airflow Logo](https://upload.wikimedia.org/wikipedia/commons/d/de/AirflowLogo.png)](https://airflow.apache.org)

**Apache Airflow** is an open-source platform designed to **author, schedule, and monitor data pipelines**.  
Workflows are defined as **Directed Acyclic Graphs (DAGs)** written in Python, giving engineers full control and flexibility over task orchestration.

### ✨ Core Features

- **Python-based DAGs:** Define complex workflows programmatically with dependencies and conditions.
- **Dynamic Scheduling:** Trigger workflows at fixed intervals, based on events, or manually.
- **Rich UI & Monitoring:** Visualize DAG runs, dependencies, and task logs in real time.
- **XComs & Task Communication:** Share small data between tasks.
- **Retry & SLA Management:** Robust handling of task failures and performance alerts.
- **Plugins & Extensibility:** Integrate with AWS, GCP, Databricks, Spark, or any custom operator.
- **Task Sensors:** Wait for events (like file creation, API responses, or DB updates) before triggering downstream tasks.

---

### Architecture 

Apache Airflow follows a **modular architecture** with components that work together to schedule, execute, and monitor workflows (DAGs).

#### 🧱 Core Components

- **Webserver (UI)**  
  A Flask-based web app that lets users view DAGs, trigger runs, monitor task status, and inspect logs.
- **Scheduler**  
  The brain of Airflow — it parses DAG definitions, schedules tasks, and sends them to the executor when their dependencies are met.
- **Executor**  
  Determines *how and where* tasks run.  
  Examples:
    - `SequentialExecutor` (local, for testing)
    - `LocalExecutor` (parallel on one machine)
    - `CeleryExecutor` or `KubernetesExecutor` (distributed scale-out)
- **Metadata Database**  
  Stores DAG definitions, task states, connections, and logs.  
  Typically runs on **Postgres** or **MySQL**.
- **Worker(s)**  
  Execute tasks as directed by the scheduler (only used in distributed executors like Celery/Kubernetes).
- **Triggerer (for deferrable tasks)**  
  Efficiently manages long waits (like sensors or async events) without blocking workers.
- **DAGs Folder**  
  Directory where Airflow scans for Python scripts defining DAGs.

#### 🔄 How It Works (High-Level Flow)

1. **DAG parsing** – The scheduler scans the DAG folder and loads all defined workflows into the metadata DB.
2. **Task scheduling** – Based on schedules or triggers, tasks are queued for execution.
3. **Execution** – The executor assigns tasks to workers (local or distributed).
4. **Tracking** – Task states and logs are stored in the metadata DB and shown in the web UI.

[![Apache Airflow Logo](https://airflow.apache.org/docs/apache-airflow/stable/_images/diagram_basic_airflow_architecture.png)](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html)

## Advanced Capabilities

- **Dynamic DAG Generation:** DAGs can be generated dynamically at runtime using Python & Yaml templating
- **Task Groups & Dependencies:** Simplify DAG readability and structure.
- **REST API:** Allows external services or CI/CD pipelines to trigger and monitor workflows programmatically.
- **Secrets Backend Integration:** Securely manage credentials via AWS Secrets Manager, HashiCorp Vault, etc.
- **Airflow Smart Sensors:** Efficiently handle thousands of waiting sensors without overloading the scheduler.

---

## Disadvantages and Industry Trade-offs

Despite its popularity, **Airflow isn’t always the right tool** for every orchestration need:

### Disadvantages

- **Operational Overhead:** Requires maintaining a scheduler, metadata DB, and workers — not ideal for small workloads.
- **Scaling Challenges:** The Celery/Kubernetes executors require additional configuration to scale reliably.
- **Latency:** Airflow is **not real-time** — designed for batch or scheduled pipelines, not streaming.
- **Complex Debugging:** Failures in dynamic DAGs or multi-dependency tasks can be difficult to trace.
- **Version Drift:** Upgrading across Airflow versions can break DAG compatibility.
- **Limited Local Development Experience:** DAG testing locally can be slow due to scheduler reliance.

### 💡 When Airflow Might *Not* Be Ideal

- For **low-latency or event-driven** data pipelines → use **Prefect**, **Dagster**, or **dbt Cloud**.
- For **microservice orchestration** → tools like **Temporal**, **AWS Step Functions**, or **Argo Workflows** may fit better.

---

## 🛠️ Setting Up Airflow with Docker Compose

This project includes a ready-to-run Docker Compose setup with:

- Airflow webserver
- Airflow scheduler
- Two Postgres databases
- Optional pgAdmin for database management

### Project Structure

Drawn in board. 

<pre>
03_Airflow/
├── compose.yml
├── solution/                          # reference solutions
│   ├── price_trend_analyzer.py        # single task
│   ├── price_trend_analyzer_tasks.py  # one task per step
│   ├── order_submitter.py             # sensor -> order_book
│   └── create_tables.sql              # auto-applied to prices-db on first start
├── dags/                              # mounted into Airflow -- work here
│   ├── price_trend_analyzer.py        # STUB
│   ├── price_trend_analyzer_tasks.py  # STUB (EmptyOperator scaffold)
│   └── order_submitter.py             # STUB
├── data/orders/                  # order JSON files written by the DAG
└── logs/                         # Airflow task logs
</pre>

---

## Services

| Service               | Description                                                                                          |
| --------------------- | ---------------------------------------------------------------------------------------------------- |
| **airflow-db**        | Postgres database for Airflow metadata. Stores DAG runs, task instances, and logs.                   |
| **prices-db**         | Dedicated Postgres database for BTC price tracking, rolling averages, and order logs. Keeps data clean and separate from Airflow metadata. |
| **pgadmin**           | Web UI to browse and manage databases. Accessible via browser.                                       |
| **airflow-webserver** | Web interface for monitoring and managing Airflow DAGs.                                              |
| **airflow-scheduler** | Core service responsible for parsing and executing DAGs based on schedule intervals.                 |

---

## How to Run

First generate a `.env` file pinning the images to your machine's architecture
(run once):

```
printf 'COMPOSE_PLATFORM=linux/%s\n' \
  "$(case $(uname -m) in arm64|aarch64) echo arm64;; *) echo amd64;; esac)" > .env
```

Then start everything:

```
docker compose up -d
```

That second command is all you need from then on. The `airflow-init` service waits until both
databases report healthy, then fixes ownership on the mounted directories,
migrates the metadata DB, creates the admin user, and registers the `prices_db`
connection. The webserver and scheduler wait for `airflow-init` to finish before
they start, so there are no manual initialization steps.

Follow the startup with:

```
docker compose logs -f airflow-init
```

Re-running `docker compose up -d` is safe -- initialization is idempotent.

### Troubleshooting

**`dependency failed to start: container prices-db is unhealthy`**

Almost always a corrupt Postgres data directory: an earlier `initdb` was
interrupted, leaving `pgdata_airflow/` or `pgdata_prices/` non-empty but without a
valid cluster. Postgres then refuses to initialize *and* cannot start. Confirm with
`docker logs prices-db` -- look for:

```
initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
```

Fix by deleting the half-written directories and starting over (this discards local
database contents, which are recreated from scratch):

```
docker compose down
rm -rf pgdata_airflow pgdata_prices
docker compose up -d
```

**Platform mismatch errors on Apple Silicon**

If you see `image ... does not match the specified platform`, your `.env` is missing
or wrong -- regenerate it with the command in *How to Run*. This happens when
`DOCKER_DEFAULT_PLATFORM=linux/amd64` is exported in your shell; the `platform:`
setting in `compose.yml` overrides it, but only if `.env` exists. Note that an
interrupted start caused by this will itself leave corrupt `pgdata_*` directories,
so you may need both fixes.

## Login credentials

Username: airflow
Password: airflow

---

## Credentials

| Component      | Username            | Password      | Port |
| -------------- | ------------------- | ------------- | ---- |
| **airflow-db** | `airflow`           | `airflow`     | 5432 |
| **prices-db**  | `prices_user`       | `prices_pass` | 5433 |
| **pgAdmin**    | `admin@example.com` | `admin`       | 5050 |

Access pgAdmin at:  
[http://localhost:5050](http://localhost:5050)

Access Airflow at:  
[http://localhost:8080](http://localhost:8080)

Connecting `prices-db` through PgAdmin

| Field                    | Value                                                |
| ------------------------ | ---------------------------------------------------- |
| **Host name / address**  | `prices-db` *(use service name from docker-compose)* |
| **Port**                 | `5432`                                               |
| **Maintenance database** | `prices_db`                                          |
| **Username**             | `prices_user`                                        |
| **Password**             | `prices_pass`                                        |

---

## Practice Assignment: BTC Price Analyzer

This hands-on assignment demonstrates a real-world use case:
tracking Bitcoin prices, calculating a rolling average, and triggering buy/sell orders based on market conditions.

### 📈 DAG: `price_trend_analyzer`

1. Fetches BTC price periodically (e.g., every minute) from CoinGecko API (no authentication required).
2. Stores it in a dedicated Postgres database (`prices-db`) in `btc_prices` table.
3. Computes 15-minute rolling average and stores in `rolling_averages`.
4. Makes a decision:

   - **BUY** if the price drops below the rolling average.
   - **SELL** if the price exceeds the rolling average.
5. Logs all results and decisions into the `orders` table.

---

## SQL Schema Setup

`solution/create_tables.sql` is mounted into the `prices-db` container's
init directory, so these tables are created **automatically** the first time the
database is initialized. You only need to run this by hand if you are working
against your own Postgres instance.

To re-apply it from scratch, remove the data directory and recreate the stack:

```
docker compose down && rm -rf pgdata_prices && docker compose up -d
```

The schema:

```sql
-- Database: prices-db
-- Replace with: CREATE DATABASE prices-db; if needed

-- Table to store raw BTC prices
CREATE TABLE IF NOT EXISTS btc_prices (
    id SERIAL PRIMARY KEY,
    ts TIMESTAMP WITH TIME ZONE NOT NULL,
    price NUMERIC(18,8) NOT NULL
);

-- Table to store rolling averages
CREATE TABLE IF NOT EXISTS btc_rolling_avg (
    id SERIAL PRIMARY KEY,
    ts TIMESTAMP WITH TIME ZONE NOT NULL,
    rolling_avg NUMERIC(18,8) NOT NULL
);

-- Table to log triggered orders
CREATE TABLE IF NOT EXISTS orders_log (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    payload JSONB,
    response JSONB,
    status VARCHAR(32)
);

-- Downstream "order book" that submitted orders land in. Stands in for an
-- external trading system: the sensor DAG submits by inserting a row here.
-- source_file is UNIQUE so the same order file cannot be submitted twice.
CREATE TABLE IF NOT EXISTS order_book (
    id SERIAL PRIMARY KEY,
    order_type VARCHAR(8) NOT NULL,
    price NUMERIC(18,8) NOT NULL,
    rolling_avg NUMERIC(18,8) NOT NULL,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    source_file TEXT NOT NULL UNIQUE
);

```

---

## Price Trend Analyzer

Complete the tasks below. Each has a stub in `dags/` to work from and a finished version in `solution/`.

### Task 1: Write your first DAG

A DAG that simulates the process of tracking Bitcoin (BTC) price movements, calculating rolling averages, and generating buy/sell signals. It performs the following key tasks:

- Fetch Latest BTC Price
- Retrieves (or simulates) the latest BTC price at each scheduled interval.
- Store Price in Database:
    - Inserts the current timestamp and price into the btc_prices table.
- Compute Rolling Average
    - Calculates a rolling average over the last 15 minutes and stores it in btc_rolling_avg.
- Analyze Price Trends
    - Compares recent prices to detect upward or downward trends relative to the rolling average.
- Trigger Buy/Sell Orders
    - If a signal is detected:
        - A Buy order is generated when prices rise above the rolling average after being below it.
        - A Sell order is generated when prices drop below the rolling average after being above it.
- Log Orders, each triggered order is:
    - Written as a JSON file under /tmp/data/orders/
    - Logged into the orders_log table for auditability.

#### DAG Schedule

The DAG runs every minute (`*/1 * * * *`), simulating continuous BTC market monitoring and analysis.
It fetches simulated price data, calculates a 15-minute rolling average, and logs potential Buy or Sell triggers.

Airflow automatically manages backfilling, meaning if the DAG was paused or Airflow was down, it can retroactively execute any missed runs to ensure data continuity.
This is especially useful in production pipelines where historical data consistency matters.

The DAG file is provided in the `solution/` folder. Copy it into `dags/`, which is
mounted into both the webserver and the scheduler:

```
cp solution/price_trend_analyzer.py dags/
```

The scheduler picks up new files within about 30 seconds -- no restart or manual
`airflow db init` required. If the DAG does not appear, check for an import error
with `docker compose logs airflow-scheduler`.

#### Database connection

The DAG reaches Postgres through an Airflow **connection** rather than a hardcoded
connection string:

```python
from airflow.providers.postgres.hooks.postgres import PostgresHook

pg = PostgresHook(postgres_conn_id="prices_db")
```

The `prices_db` connection is registered automatically by `airflow-init`, so it is
ready to use. You can inspect it in the UI under **Admin -> Connections**, or from
the command line:

```
docker compose exec airflow-scheduler airflow connections get prices_db
```

Use this same `prices_db` connection ID in the DAG you write for the extension
exercise below.

The DAG (price_trend_analyzer.py) is located in the solution/ folder. When setting up Airflow, you need to copy this file into the Airflow DAGs directory:

### Task 2 : Decompose the DAG into one task per step

Consider the stub in `dags/price_trend_analyzer_tasks.py` for this exercise. Every step is an `EmptyOperator` -- a placeholder that does nothing and always succeeds -- so the DAG is already green end to end before you write a line of logic.  The decomposed version shall produce this graph:

```
fetch_price -> store_price -> compute_rolling_average -> decide_order -> record_order
```

**Your job:** replace each `EmptyOperator` with a `PythonOperator` that calls the matching function in the same file, working left to right.

Then, trigger it once and look at the Graph view: you get the shape of the pipeline first, then fill it in, and the graph never breaks while you are half-finished. Compare the single-task version and the split version. **What does the latter buys?** 3 things:

- **Targeted retries.** Only `fetch_price` touches the network, so only it needs
  aggressive retries (`retries=3`). In the monolith, a transient API error re-runs
  the database writes as well.
- **Failure localisation.** Each step gets its own log and status, so a red square
  in the Grid view names the step that broke.
- **Independent testing.** Steps can be exercised one at a time:

  ```
  docker compose exec airflow-scheduler \
    airflow tasks test price_trend_analyzer_tasks compute_rolling_average 2026-01-01
  ```

  Note that a task tested in isolation this way cannot read XCom values from
  upstream tasks that never ran. To exercise the whole chain, run the DAG instead (as below, or from the UI):

  ```
  docker compose exec airflow-scheduler airflow dags test price_trend_analyzer_tasks
  ```

#### Use XCom

Steps pass values to each other through **XCom**. Keep the `task_id` strings exactly as given: `xcom_pull` refers to tasks by name. Returning a value from a `PythonOperator` callable pushes it; downstream tasks read it with `ti.xcom_pull(task_ids="...")`. XCom payloads are serialized into the metadata database, so it is strictly for small values -- a price and a timestamp here, never a dataset. To hand a large result between tasks, write it to shared storage and pass the path.

```
fetch_price -> store_price -> compute_rolling_average -> decide_order -> record_order
```

1. **`fetch_price`** -- call the price API, return the price and timestamp.
   This is the only step that touches the network, so give it
   `retries=3` while the others inherit the default. Return the timestamp as a
   *string*: XCom serializes to JSON and a `datetime` does not round-trip.
1. **`store_price`** -- `xcom_pull` the payload and insert into `btc_prices`.
1. **`compute_rolling_average`** -- average the last 15 minutes, insert into
   `btc_rolling_avg`, and return the value. Bound the window at *both* ends
   (`>= cutoff AND <= ts`) so re-running an old interval cannot read rows newer
   than the run itself.
1. **`decide_order`** -- compare the last 4 prices against the average and return
   an order dict, or `None` when there is no signal. Fewer than 4 prices is the
   normal state for the first few runs, not a failure.
1. **`record_order`** -- write the order JSON and log it to `orders_log`.

**Run the whole chain:**

```
docker compose exec airflow-scheduler airflow dags test price_trend_analyzer_tasks
```

Testing a single task in isolation works only for `fetch_price`. The others read
XCom values from upstream tasks, and a lone `airflow tasks test` has none, so they
fail with `TypeError: 'NoneType' object is not subscriptable`. That is expected --
not a bug in your code.

**Questions to answer when you are done:**

- Which task would you retry, and which would you not? What breaks if
  `store_price` retries after `fetch_price` already succeeded?
- The single-task version renders as one box in the Graph view. What can you see
  in the Grid view now that you could not before?
- `decide_order` returns `None` on most runs and `record_order` then does
  nothing. How else could you express "stop here" in Airflow, and what would the
  Grid view show in that case?
- Where would you split this further if the price API were replaced by ten
  different exchanges?

Deploy whichever version you want to run:

```
cp solution/price_trend_analyzer_tasks.py dags/
```

### Task 3 — Order Trigger

This part builds on the **Price Trend Analyzer** DAG and introduces event-driven orchestration using Airflow sensors.

Once the first DAG generates an order JSON file (in `/tmp/data/orders`), this
second DAG should automatically detect it and **submit the order to the order
book** -- the `order_book` table in `prices-db`, which stands in for a downstream
trading system. There is no external API to call: submitting an order means
writing a row.

Start from the stub in `dags/order_submitter.py`. Target graph:

```
wait_for_order_file -> read_order -> submit_order -> log_submission
```

#### Requirements

1. **File Sensor**

   - Use a `FileSensor` to watch `/tmp/data/orders` for `order_*.json` files
     written by the analyzer DAG.
   - Set `mode="reschedule"` so the sensor frees its worker slot between checks
     instead of holding one for the full timeout.
1. **Read the order**

   - The sensor only reports that *some* file matched, not which one. Pick the
     oldest `order_*.json` and parse it.
1. **Submit to the order book**

   - Insert `order_type`, `price`, `rolling_avg`, and `source_file` into
     `order_book`.
   - `source_file` is `UNIQUE`: submitting the same file twice violates the
     constraint. Make the insert idempotent with
     `ON CONFLICT (source_file) DO NOTHING ... RETURNING id`, and use whether a
     row came back to tell a fresh submission from a duplicate.
1. **Retry configuration**

   - Set `retries=3` and `retry_delay=timedelta(seconds=5)` in `default_args`.
   - Note what you are *not* writing: no loop, no `time.sleep`, no attempt
     counter. Airflow owns retry behaviour, and a task that raises is retried
     according to that configuration.
1. **Log the outcome**

   - Insert `payload`, `response`, and `status` into `orders_log` for every run,
     whether the submission was fresh or a duplicate.
   - Then rename the processed file (e.g. append `.done`). Leave it in place and
     the sensor matches it again on the next run, resubmitting forever.

Reference solution: `solution/order_submitter.py`.

### 🛰️ Airflow Sensors — Waiting for External Events

**Sensors** in Apache Airflow are *special operators* that **wait for a condition to be true** before allowing downstream tasks to continue.

They are useful when your pipeline depends on **external events or data availability** — for example:

- Waiting for a file to appear in a folder (e.g., on S3 or local filesystem)
- Waiting for a table or partition to be ready in a database
- Waiting for another DAG or task to finish

#### 🧩 How Sensors Work

A sensor is just like any other operator but runs in a *loop*, periodically checking a condition.

```python
from airflow.sensors.filesystem import FileSensor

wait_for_file = FileSensor(
    task_id="wait_for_btc_order_file",
    fs_conn_id="fs_default",
    filepath="/tmp/data/orders/order_*.json",  # glob patterns work
    poke_interval=30,  # check every 30 seconds
    timeout=600,       # give up after 10 minutes
)
```

`fs_conn_id` refers to an Airflow connection of type *File (path)*. It normally
arrives with Airflow's example connections, but this project disables those
(`AIRFLOW__CORE__LOAD_EXAMPLES: "false"`), so `airflow-init` creates `fs_default`
explicitly. A sensor pointed at a connection that does not exist fails with
`AirflowNotFoundException: The conn_id 'fs_default' isn't defined` -- worth
recognising, because the sensor simply retries and the DAG appears to hang.

#### 🧩🧩 Resource efficiency

Default mode ("poke"): blocks the worker slot while waiting.

Recommended: mode="reschedule": releases the slot between checks → frees resources.

Example:

```python
wait_for_btc_order_file = FileSensor(
    task_id="wait_for_btc_order_file",
    filepath="/tmp/data/orders/order.json",
    mode="reschedule",
    poke_interval=30,
    timeout=600
)
```

#### 🧠 Goal

This exercise demonstrates **event-driven DAG triggering**, **sensor-based workflows**, and **robust API interaction with retry logic** — key concepts in production-grade data pipelines.

### Discussion Pointers

* Why batch scheduling still matters in modern data pipelines.
* How Airflow compares to Prefect and Dagster in orchestration.
* When to replace task-based DAGs with event-based architectures.
* Common scaling pitfalls and deployment best practices.