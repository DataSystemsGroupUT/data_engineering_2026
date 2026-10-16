# Plan: two-hour Superset and Streamlit practice

Status: implemented as a student-facing draft on 30 September 2026; integrated with the cleaned main branch and renamed to `06_Visualization` on 16 October 2026. Automated data, application, and Superset browser checks pass; the full Docker and timed student walkthrough remains open. This plan follows the [baseline audit](AUDIT.md) and points to the [new practice](README.md).

## Session outcome and boundary

Week 7 on **20 October 2026** is “Data visualization: Streamlit and Superset” in the [course inventory](../README.md). In 120 minutes, each student should use the same small, curated PostgreSQL dataset to build a Superset dashboard and make one meaningful change to a Streamlit dashboard. The result should answer a concrete sales question and name one limitation of its metric. This builds on weeks 1–3 (Docker, PostgreSQL, relational and dimensional models) without requiring the legacy ClickHouse lesson or a complete ingestion pipeline.

Suggested question: **Which product categories and regions deserve attention in the selected sales period?** The sample is fictional; avoid claims about real-world performance. Define gross sales as `SUM(sales_amount)` and distinguish it from profit and order count.

## Target environment and install path

| Component | Decision | Why |
| --- | --- | --- |
| Analytics data | One `postgres:16.4` server, with a `viz_practice` database and seeded `analytics` schema | Reuses the image from earlier course practices. A deterministic seed makes the first exercise reliable. |
| Superset metadata | A separate `superset_meta` database on the **same** PostgreSQL server | Keeps internal Superset tables out of the student dataset without adding another server. |
| Superset | Official `apache/superset:6.1.0` image with a small Dockerfile that installs `psycopg2-binary==2.9.11`, plus one-time init service | The [6.1.0 release image is lean](https://superset.apache.org/admin-docs/6.1.0/installation/docker-builds/) and lacks this driver. A small layer avoids the moving `latest-dev` image and copied upstream source. No Redis, worker, or beat. |
| Streamlit | Small Python image with `streamlit==1.64.0`, `pandas==2.3.3`, and `psycopg[binary]==3.3.6` | One guided app using the same SQL view. No host Python setup and no weather pipeline. |
| Credentials | Ignored `.env` copied from a local demo template, local admin, read-only `viz_reader` for analytics | Keeps startup reproducible and makes the difference between metadata access and chart-data access visible. Ports remain private on localhost. |

The student path is: create a separate `superset-practice` folder, copy the small supplied file set into it while preserving subfolders, copy `.env.example` to `.env`, run `docker compose up -d --build` from that folder, check `docker compose ps -a` and the init log, then open Superset on `localhost:8088` and Streamlit on `localhost:8501`. A local checkout or downloaded ZIP supplies the files; students do not need to edit the course copy. The guide includes Bash and PowerShell copy commands, port-conflict guidance, and a Codespaces private-port note. Students should not edit Compose or install a database driver during class.

The database should start healthy before Superset init and Streamlit, and Superset should start only after init completes. Bind PostgreSQL data to local `./pgdata`, as in the earlier course practices, and ignore that folder in Git. A normal `docker compose down` preserves work. A fresh seed requires stopping the stack and moving `pgdata/` aside; `down -v` does not remove a bind mount. Avoid default “last week” chart filters when the seed is historical.

### Python dependency workflow decision, autumn 2026

Keep `pip install -r requirements.txt` inside the small Streamlit Docker build for this two-hour visualization practice. Students run the supplied app and change one widget; teaching a project dependency manager here would take time from comparing Superset and Streamlit. The three pinned entries in `requirements.txt` fix direct versions but do **not** lock every transitive dependency, so avoid claiming a fully reproducible Python environment.

Consider **uv** when the course next teaches students to create and maintain their own Python application: use `pyproject.toml` for project dependencies, commit `uv.lock`, and teach `uv add`, `uv sync --locked`, and `uv run` as one workflow. The [current uv Docker guide](https://docs.astral.sh/uv/guides/integration/docker/) supports copying pinned uv binaries from its minimal image into `python:slim`, or using uv only during the build; there is no need to base the whole runtime on a larger combined uv/Python image. Merely replacing `pip install` with `uv pip install` here might speed a build, but would not teach that project workflow. Revisit only if a measured classroom build or download delay warrants it.

## Data and teaching assets

1. Preserve the supermarket domain and reuse suitable fields from the present CSVs. Expand to a **deterministic, modest** dataset spanning several weeks and at least two months, regions, and categories. No live API dependency. Document row count, date range, and expected totals so students can check the startup result.
2. Seed one clear fact/dimension example and a curated view such as `analytics.sales_enriched` with `sale_date`, `region`, `category`, `quantity`, `sales_amount`, and a stable row grain. Give both tools read access to this same view. Include a short note on why joins and metric definitions belong in a serving layer.
3. Provide one concise SQL Lab query and a reference result. Define gross sales once, at dataset level where the UI supports it. Keep SQL dataset creation as an optional comparison with a physical table/view; explain the grain to avoid double counting.
4. Provide a runnable **starter** Streamlit app, deliberately leaving a small student edit: add or modify a category/region selection, metric, or chart. Use `st.metric`, `st.multiselect` or `st.selectbox`, a built-in chart, `st.dataframe`, and a caption with the snapshot date. Load from PostgreSQL with a bounded query; use `st.cache_data` with an explicit short TTL if useful. Explain reruns and empty selections. Use the [weather project](https://github.com/KristoR/ut-andmeinseneeria-2026/tree/main/projekt/naidisprojekt-ilmaandmed) as the richer project example, not as code to copy wholesale.
5. Finish with a comparison: Superset for quick self-service exploration and shared dashboards; Streamlit when the presentation or interaction needs Python logic. Have students check that one filtered metric agrees across both tools. Explain that identical charts are unnecessary; the shared metric and filter semantics matter. Mention dashboard ZIP export as a backup of the dashboard and related chart/dataset/connection definitions; the PostgreSQL data and resolvable connection remain separate requirements.

## 120-minute core agenda

| Minutes | Activity | Checkpoint |
| --- | --- | --- |
| 0–10 | Visual story and architecture; identify source data, curated view, two consumers | State the business question and gross-sales definition. |
| 10–20 | Start the prebuilt Compose environment; verify data and both pages | Expected row count and date range visible; Superset login works. |
| 20–35 | Add a read-only PostgreSQL connection in Superset; use SQL Lab to inspect the serving view | Query result agrees with reference totals. |
| 35–60 | Register the dataset and build a trend, category comparison, and KPI | Charts display historical sample data; axes and units are labeled. |
| 60–80 | Arrange dashboard, add region/category filters and a two-sentence interpretation | Filter changes all relevant charts; note gross-sales limitation. |
| 80–105 | Open starter Streamlit app, add a category widget, watch rerun | App works with a selection and handles an empty selection. |
| 105–115 | Compare the same filtered figure in Superset and Streamlit; discuss tool choice | Numbers agree or discrepancy is explained. |
| 115–120 | Save/export a screenshot or link for class review; stop services | Dashboard and app can be restarted with data intact. |

This leaves manual creation of database roles, manual database loading, CI, live ETL, dbt rebuilds, scheduled reports, Superset role administration, and API serving outside the core. A short optional extension may show how an existing project PostgreSQL mart or the legacy ClickHouse warehouse can replace the seeded data source.

## Revision status and remaining gate

- [x] Replace the previous Compose stack with one PostgreSQL container, pinned Superset 6.1.0 plus its driver, one-time init, and one Streamlit app. Remove copied upstream development files from the active lesson; git history retains them.
- [x] Add a versioned `.env.example` template with an ignored local `.env`, deterministic SQL seed, and a minimal Streamlit app with pinned dependencies. The student edit is one marked category-widget line.
- [x] Rewrite [`README.md`](README.md) around the timed agenda: startup, expected outputs, Superset actions, Streamlit edit, comparison, troubleshooting, cleanup, and optional project extension. Update the course inventory to point to it.
- [x] Align the lesson folder with the active course sequence and repair root README links to the ER, combined MongoDB/Neo4j, and archived lessons. Provide Bash and PowerShell workspace and `.env` copy commands before the first Compose command.
- [x] Validate Compose configuration, the PostgreSQL seed and reader permissions, database restart and fresh setup, and both the Streamlit starter and student category-widget edit using the pinned dependencies.
- [x] Exercise the published Superset image's driver installation, initialization twice, SQL Lab, dataset and metric creation, chart queries, and dashboard export. Verify browser login, rendering of three charts, native filters scoped to all charts, and clearing filters.
- [ ] Run the **full Docker Compose stack** from a separate practice folder with fresh `pgdata/`: image builds, service readiness, both browser pages, the Streamlit edit/rerun, normal stop/restart, and moving the data folder aside for reset. Follow the Superset chart/dashboard creation steps manually and execute the Windows copy commands.
- [ ] Time a first-run walkthrough including image pull/setup. The guide includes pre-class image-pull instructions; adjust the 10-minute setup window if needed.

The lesson revision should not be considered ready solely because Compose parses. The acceptance condition is that a student starting from a separate practice folder can complete the two visual outputs and explain a consistent metric within 120 minutes.

## Validation on 16 October 2026

| Area | Verified result |
| --- | --- |
| Workspace and configuration | Bash copying preserves hidden files and subfolders; Compose 5.5.1 validates the separate workspace after `.env` is copied. Shell/Python syntax checks pass. All 58 relative links in the repository's 19 README files resolve. PowerShell commands were reviewed, not executed. |
| PostgreSQL 16.4 | The supplied initialization and seed produce 1,104 rows from 1 July to 30 September 2026, €16,835.80 overall, and €2,920.00 for South + Household. Reader permissions prevent changes to lesson data and direct access to the underlying tables. Restart retains the data; a fresh cluster reproduces the same figures. |
| Streamlit 1.64.0 | AppTest with Python 3.12.15, the exact pinned dependencies, and real PostgreSQL passes for the starter and the README's category-widget edit. Region/category selections, empty selections, restored selections, KPIs, displayed rows, and both charts agree. The dataframe uses the supported `width="stretch"` parameter. |
| Superset 6.1.0 | The published ARM64 image accepts the Dockerfile's PostgreSQL driver installation. Its shipped initialization exits 0 on fresh and repeat runs. HTTP login, CSRF, the reader connection, SQL Lab, dataset registration, and the saved metric work. Browser checks render the KPI, 92-day line, and four-category bar chart; applying South + Household changes all three charts and shows €2,920.00, while clearing filters restores €16,835.80. Export includes the dashboard, three charts, dataset, and database definition. |

The Superset image was unpacked and run in an isolated filesystem against native PostgreSQL because this workspace has no Docker engine. These checks exercise the released application and image setup commands, but do not verify Docker builds, Compose networking, or container lifecycle. The remaining Docker and timed student walkthroughs above are still required.
