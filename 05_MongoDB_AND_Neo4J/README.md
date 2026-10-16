# ⏱️ Week 6 In Class — Documents and Graphs in 90 Minutes

A **short, combined** session covering both stores from week 6: MongoDB and
Neo4j, side by side, in one 90-minute slot.

> **This is the short version.** It does not replace the full practices —
> [`../05_MongoDB/`](../05_MongoDB/README.md) and
> [`../05_Neo4J/`](../05_Neo4J/README.md), each ~90 min on its own, plus a ~3h
> homework. Those stay exactly as they are. This folder exists because 180
> minutes of material does not fit in a 90-minute class.

## What this session is for

Not fluency in two query languages — there is no time for that. The goal is
**judgement**: given a question, knowing which store answers it naturally.

The session therefore spends its last third on the part the separate practices
cannot do: asking **the same four questions of both databases** and watching
which one reads cleanly and which one fights back.

## Agenda (90 minutes)

| Time   | Part            | What students do                                   |
| ------ | --------------- | -------------------------------------------------- |
| 10 min | 0. Setup        | Start both databases, load both datasets           |
| 25 min | 1. MongoDB      | Documents, nested fields, arrays, one aggregation  |
| 25 min | 2. Neo4j        | Nodes, relationships, a traversal, one aggregation |
| 20 min | 3. Head to head | The *same* four questions against both             |
| 10 min | 4. Wrap-up      | Scorecard, rule of thumb, discussion               |

Four short **✏️ Your turn** exercises (3–4 min each), each with a solution
immediately beneath it — enough to make students type Cypher and pymongo
themselves without stalling the room.

## Learning objectives

By the end of the session, students can:

1. Read and write a basic MongoDB query and a basic Cypher pattern.
2. Explain why a document holds nested data and a graph holds relationships.
3. Name a question each store answers *better* than the other, and say why.
4. Decide, for their group project, which store fits — and what it costs.

## Setup

Everything runs from this folder:

```bash
docker compose up -d     # MongoDB + Neo4j + one JupyterLab for both
./load.sh                # imports both datasets, safe to re-run
```

The first start builds the notebook image (a couple of minutes); after that it
is cached. Then open **<http://localhost:8890>** and start
[`notebooks/InClass.ipynb`](notebooks/InClass.ipynb).

| Service       | URL / command                                                                         | Credentials          |
| ------------- | ------------------------------------------------------------------------------------- | -------------------- |
| JupyterLab    | <http://localhost:8890>                                                               | none                 |
| Neo4j Browser | <http://localhost:7474>                                                               | `neo4j` / `password` |
| Mongo shell   | `docker exec -it mongodb mongosh -u admin -p password --authenticationDatabase admin` |                      |
| Cypher shell  | `docker exec -it neo4j cypher-shell -u neo4j -p password`                             |                      |

> ⚠️ **Do not run this stack and the full `05_MongoDB` / `05_Neo4J` stacks at the
> same time.** They deliberately reuse the same database ports (27017, 7474,
>
> 7687) so the commands students already know still work. Only JupyterLab moves,
>
> to 8890, so it cannot clash with either (8889 / 8888). Run `docker compose
> down` in one folder before `up` in another.

The datasets are **read from the full practice folders** (`../05_MongoDB/sample_data`
and `../05_Neo4J/sample_data`), not copied — one source of truth, so fixing data
in a practice folder fixes it here too.

When finished:

```bash
docker compose down
```

No named volumes are declared, so this leaves nothing behind.

## Files

```
05_InClass_90min/
├── compose.yml            # MongoDB + Neo4j + JupyterLab, all three at once
├── notebook.Dockerfile    # one image with pymongo AND the neo4j driver
├── load.sh                # imports both datasets, idempotent
├── notebooks/
│   ├── InClass.ipynb            # the session -- project this one
│   └── InClass_Instructor.ipynb # 👩‍🏫 your copy: solutions + talking points
└── README.md
```

## What was cut from the bigger practices

Worth saying out loud in class, so students know what they are missing:

| Cut                                                 | Where it lives |
| --------------------------------------------------- | -------------- |
| Update operators (`$set`, `$inc`, `$push`, `$pull`) | 05_MongoDB §7  |
| `explain()`, indexes, query plans                   | 05_MongoDB §8  |
| `MERGE` / `SET` / `DETACH DELETE`                   | 05_Neo4J §7    |
| `PROFILE`, indexes, `allShortestPaths`              | 05_Neo4J §8    |
| Challenge scenarios (5 each)                        | both, §9       |
| Modelling a schema yourself                         | both homeworks |

The notebook flags these inline at the end of Parts 1 and 2, with links, so the
omissions are visible rather than silent.

