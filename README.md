# Data Engineering — Fall 2026

Practice session materials for the University of Tartu Data Engineering course, Fall 2026.
The course covers data collection, relational and dimensional modeling, transformation,
workflow orchestration, and visualization. Students apply these skills in a group project
that develops a complete data engineering product.

This repository provides practice instructions, Docker Compose environments,
sample datasets, SQL and Python examples, and reference solutions.

- [Course overview](https://courses.cs.ut.ee/2026/dataeng/fall/)
- [Lecture and practice schedule](https://courses.cs.ut.ee/2026/dataeng/fall/Main/Lectures)
- [Project requirements and assessment](https://courses.cs.ut.ee/2026/dataeng/fall/Main/Grading)
- Moodle: lecture recordings, quizzes, submissions, and course announcements.

## Weekly practical sessions

Use the weekly inventory to find practice instructions and prepare for class.
Weeks follow the 2026 course schedule; folder numbers are lesson identifiers.
**Update needed** marks materials awaiting revision for this year's course or
instructions that are missing from the repository.

| Week | Practice date | Session | Materials | Status |
| --- | --- | --- | --- | --- |
| 1 | 8 Sep 2026 | Docker and PostgreSQL | [Docker practice](00_Docker/README.md) | Ok |
| 2 | 15 Sep 2026 | Relational modeling and ER diagrams | [ER practice](01_ER/assignment/README.md) | Ok |
| 3 | 22 Sep 2026 | Dimensional modeling and star schemas | [Star schema practice](02_Star_Schema/README.md) | Ok |
| 4 | 29 Sep 2026 | Workflow orchestration with Airflow | [Airflow practice](03_Airflow/README.md) | Ok |
| 5 | 6 Oct 2026 | Data transformation with dbt | [dbt practice](04_dbt/README.md) | Ok |
| 6 | 13 Oct 2026 | Semi-structured data: MongoDB and Neo4j | [MongoDB practice](05_MongoDB/README.md); [Neo4j practice](05_Neo4J/README.md) | Ok |
| 7 | 20 Oct 2026 | Data visualization: Streamlit and Superset | [Superset practice](11_Superset/README.md); Streamlit materials missing | Update needed |
| 8 | 27 Oct 2026 | Project work | | |
| 9 | 3 Nov 2026 | Project work | | |
| 10 | 10 Nov 2026 | Project work | | |
| 11 | 17 Nov 2026 | Project work | | |
| 12 | 24 Nov 2026 | Project work | | |
| 13 | 1 Dec 2026 | Project work | | |
| 14 | 8 Dec 2026 | Project work | | |
| 15 | 15 Dec 2026 | Project work | | |
| 16 | 18 Jan 2027 | Project presentations and poster session | | |

## Working with the practice materials

Start with the Docker practice to prepare your environment. Each session's
instructions describe the required services, setup commands, and exercises. Run
commands from the directory specified in the lesson. Assignment folders include
task descriptions and, where provided, reference solutions.

Students should follow the session instructions together with the guidance given
in class.

## Legacy lessons

Additional reference exercises from earlier course editions. These topics have
no standalone practical session in the 2026 schedule.

| Status | Topic | Repository instructions |
| --- | --- | --- |
| Legacy | ClickHouse: analytical storage, star schemas, and queries | [05_ClickHouse](05_ClickHouse/README.md) |
| Legacy | Iceberg with DuckDB, PyIceberg, and MinIO | [08_Iceberg](08_Iceberg/README.md) |
| Legacy | Security and privacy: permissions, masking, and auditing | [09_Security_Privacy](09_Security_Privacy/README.md) |
| Legacy | OpenMetadata: cataloging, data quality, and lineage | [10_OpenMetadata](10_OpenMetadata/README.md) |

The existing dbt and Superset practices use ClickHouse; the legacy ClickHouse
lesson provides supporting setup instructions and sample data.
