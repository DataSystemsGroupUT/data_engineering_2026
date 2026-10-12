# Visualization practice audit — autumn 2026

Audited 29 September 2026 against the **previous lesson** at commit `dbd5aa0`. This is a historical baseline for the [revised practice](README.md) and [plan](PLAN.md), based on repository files, the [2026 course inventory](../README.md), linked examples, and upstream documentation. Removed legacy files remain available in git history.

## Verdict

The present lesson is a useful Superset feature checklist, but it does not fit week 7 as written. Week 7 is a **two-hour Streamlit and Superset** session; [ClickHouse is a legacy lesson](../README.md), and no Streamlit task exists here. Most of this folder is a copied Superset development environment. The analytical database needed by the lesson is absent from its Compose file, so `docker compose up -d` alone cannot reach Task 1.

| Area | Current state | Consequence / decision |
| --- | --- | --- |
| Course alignment | Superset + ClickHouse only; references “Project 3” and an optional security exercise | Teach visualization and serving on PostgreSQL, already introduced in week 1. Make Streamlit a core task; leave ClickHouse integration as an optional extension. |
| Startup | Five Superset services plus an instructed manual ClickHouse addition and SQL loading | Replace with a small, self-contained course Compose setup and automatic deterministic data seeding. |
| Reproducibility | `latest-dev` image and copied upstream source, scripts, and environment file | Pin one released Superset image and keep only course-owned configuration. |
| Exercise depth | SQL Lab, dataset, chart, dashboard steps are present, but success criteria and interpretation are thin | Keep these skills; add a business question, metric definition, dashboard filter, one written insight, and a small Streamlit app using the same data. |
| Data | Six sales rows across 18–20 September 2025, all in one month | Replace or expand the seed so a time chart and date filter are meaningful. Explicitly select an all-data range for historical sample data. |

## What the previous `11_Superset/compose.yml` declared

“Installed” here means **declared by the repository**, not confirmed running on a student machine. Docker is unavailable in this workspace, so container startup and the actual image contents were not tested.

| Service | Image / source | Role |
| --- | --- | --- |
| `redis` | `redis:7` | Superset cache and Celery broker/results backend. |
| `db` | `postgres:16` | Superset **metadata** database, not the `supermarket` analytics database. |
| `superset-init` | `apachesuperset.docker.scarf.sh/apache/superset:${TAG:-latest-dev}` | One-time migrations, admin creation, permissions; runs the copied bootstrap script. |
| `superset` | Same image | Web app on host port 8088, using the copied `/app/docker` scripts. |
| `superset-worker` | Same image | Celery background worker. |
| `superset-worker-beat` | Same image | Celery scheduler. |

There were **six Compose services**: five remained active after the init job exited. The old `./docker` and `./superset-core` directories were mounted into Superset images. The checked-in `docker/.env` enabled `DEV_MODE=true` and contained example credentials; `docker/docker-bootstrap.sh` could reinstall the application in editable mode and installed `clickhouse-connect` from `requirements-local.txt` during container startup. The image tag was mutable and could drift away from those copied files. The old `superset-core` package identified itself as `0.0.1rc2`; this was a source snapshot, **not** a pin for the running Superset server.

There was **no ClickHouse service** in that Compose file. The old README asked students to paste one in, mount `sql/` and `sample_data/`, run two ClickHouse SQL files, create a service account, and then add a Superset connection. Thus the apparent five-service “Superset install” did not prepare the data source it taught.

## Specific instructional defects

1. The old README budgeted 10–15 minutes for startup and about 45–60 minutes for Superset tasks, with no two-hour agenda or Streamlit work. It told students to use default `admin/admin` credentials but the checked-in env did not explicitly set `ADMIN_PASSWORD`; that default came from the copied init script.
2. The sample CSVs contain six fact rows, three dates, one month, two regions, and four product categories. “Monthly Sales” gives one month; the original date range is now more than a year old. A default recent Superset time filter can hide the whole sample.
3. Task 4 mixes a `FactSales` chart with a joined dataset. `FullDate` **does** exist on `FactSales`, but `Region` and `Category` do not; the instructions should be explicit about which dataset supports each chart. The suggested SQL dataset is already aggregated, so asking students to sum it again needs a clear grain explanation.
4. There is no preflight check for Compose readiness, data row counts, driver availability, hostnames/ports, or a recovery path for a failed init. The lesson requires manual SQL and service-account work before any visualization.
5. The bundled `docker/README.md` was upstream development documentation. It mentioned files and services that did not exist in this folder (for example, `docker-compose-non-dev.yml` and frontend development). This was confusing as course installation guidance.
6. Security/role exercises in the appendix and “Project 3” text belong to optional project work, not the core 120 minutes. The course inventory does not schedule the legacy security lesson this year.

## What the linked examples contribute

| Reference | Useful for this course | Keep outside this two-hour core |
| --- | --- | --- |
| [Base Superset practice](https://github.com/KristoR/ut-andmeinseneeria-2026/tree/main/09-arianalyytika-ja-serveerimine/baastase) | A business question, starter check, explicit chart fields, dashboard filter, short data story, metric limitations, troubleshooting. | Source API, scheduler, microbatches, dashboard import, and freshness polling. Its stated duration is 2–2.5 hours **for Superset alone**. |
| [Advanced Superset practice](https://github.com/KristoR/ut-andmeinseneeria-2026/tree/main/09-arianalyytika-ja-serveerimine/edasijoudnud) | PostgreSQL connection, SQL Lab, curated marts, reusable metric, dashboard composition, serving-layer discussion. | dbt build, pgduckdb, FastAPI, extra metadata DB, and role/cache exercises. They duplicate other topics or displace Streamlit. |
| [DECM course](https://github.com/adlerpriit/decm_course) | A practical PostgreSQL → Superset mart workflow and small SQL snippets; separate bootstrap and app steps are a useful model. | Its custom Superset image, large environment, Airflow, dbt and live ETL are designed for another course sequence. It pins Superset 6.0.0, older than the current stable release. |
| [Weather project Streamlit dashboard](https://github.com/KristoR/ut-andmeinseneeria-2026/tree/main/projekt/naidisprojekt-ilmaandmed) | Show how a Python app reads a PostgreSQL mart, exposes filters, a KPI, a chart, a table, and last-load context. Use it as a project-sized reference. | Its weather API pipeline, cron, complex scoring, Altair composition, auto-refresh, and full app implementation. |

## Current 2026 installation recommendation

As checked on 29 September 2026, [Superset 6.1.0](https://github.com/apache/superset/releases/tag/6.1.0) was the latest official stable release, published 13 May 2026. Its **[6.1.0 image documentation](https://superset.apache.org/admin-docs/6.1.0/installation/docker-builds/)** says that the standard `apache/superset:6.1.0` image is *lean* and has **no PostgreSQL driver**. The mutable Next documentation describes a later, different image layout. The [`6.1.0` image tag](https://hub.docker.com/r/apache/superset/tags) exists for Linux amd64 and arm64. Superset’s [quickstart](https://superset.apache.org/user-docs/quickstart/) showed tag `6.0.0`; the release record was used when selecting the course pin.

**Use `apache/superset:6.1.0` plus a tiny image layer installing `psycopg2-binary`** in a course-owned Compose file, with one PostgreSQL server for two logical databases (Superset metadata and teaching data), a one-time Superset init job, and a Superset web service. Add one Streamlit service for the second half. This is three long-running services, plus the init job. Seed PostgreSQL automatically; connect both frontends to one read-only analytics role. Do not clone Superset source or mount upstream development scripts for a visualization lesson. The upstream [Compose guide](https://superset.apache.org/admin-docs/installation/docker-compose/) remains a reference for running Superset’s own development stack, not the course instructions.

Use a pinned, minimal Streamlit dependency set in its own Python container; [Streamlit’s installation guide](https://docs.streamlit.io/get-started/installation/command-line) documents `streamlit run`. The current [PyPI version](https://pypi.org/project/streamlit/) is `1.64.0` on the audit date; test and pin that version when implementing the app. Keep the database and dashboard on one Compose network, with `db` as the internal hostname. Expose only the web ports needed by students; explain that `localhost` inside a container is different from `localhost` on the host.

The proposed local Compose setup is for teaching, not a production deployment. Keep local credentials in an ignored `.env`, bind web ports to localhost, and preserve dashboards under `./pgdata` as in the other PostgreSQL practices. Explain that `docker compose down` preserves this folder and that a fresh seed requires moving it aside; `down -v` does not remove a bind mount.

## Audit limits

This audit used static repository inspection, cloned public examples, upstream release/docs, and registry metadata. It did not run `docker compose` or verify the Superset 6.1.0 UI because the `docker` executable is not available in this workspace. Those checks are required before publishing the revised practice.
