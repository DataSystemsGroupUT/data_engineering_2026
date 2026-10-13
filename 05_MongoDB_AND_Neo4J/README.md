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

| Time | Part | What students do |
| --- | --- | --- |
| 10 min | 0. Setup | Start both databases, load both datasets |
| 25 min | 1. MongoDB | Documents, nested fields, arrays, one aggregation |
| 25 min | 2. Neo4j | Nodes, relationships, a traversal, one aggregation |
| 20 min | 3. Head to head | The *same* four questions against both |
| 10 min | 4. Wrap-up | Scorecard, rule of thumb, discussion |

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

| Service | URL / command | Credentials |
| --- | --- | --- |
| JupyterLab | <http://localhost:8890> | none |
| Neo4j Browser | <http://localhost:7474> | `neo4j` / `password` |
| Mongo shell | `docker exec -it mongodb mongosh -u admin -p password --authenticationDatabase admin` | |
| Cypher shell | `docker exec -it neo4j cypher-shell -u neo4j -p password` | |

> ⚠️ **Do not run this stack and the full `05_MongoDB` / `05_Neo4J` stacks at the
> same time.** They deliberately reuse the same database ports (27017, 7474,
> 7687) so the commands students already know still work. Only JupyterLab moves,
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

## Teaching from two screens

[`notebooks/InClass_Instructor.ipynb`](notebooks/InClass_Instructor.ipynb) is the
companion to read from while the students work:

- **Every query filled in** — nothing commented out, nothing to open.
- **Talking points per query**: what to say, what to point at, the question to
  ask the room, and the mistake students actually make.
- **Cross-referenced** as `[student 14]` against cell indices in the student
  notebook, so the two stay in step.
- **A cut-list in priority order**, for when the room runs slow, and a flag on
  the three cells never to cut.
- **An appendix** of the questions that come up every year ("can't Postgres do
  all this?", "which is faster?") with short honest answers.

Open it as a second JupyterLab tab, or in a separate browser window on your
other screen. It runs its **own kernel and its own connections**, so running
cells there does not touch the student notebook — and it only reads, so it is
safe to re-run mid-class. Both notebooks executing at once has been tested.

> The solutions also remain in the student notebook's collapsed `<details>`
> blocks, so students who work ahead are not blocked.

## What is deliberately cut

Worth saying out loud in class, so students know what they are missing:

| Cut | Where it lives |
| --- | --- |
| Update operators (`$set`, `$inc`, `$push`, `$pull`) | 05_MongoDB §7 |
| `explain()`, indexes, query plans | 05_MongoDB §8 |
| `MERGE` / `SET` / `DETACH DELETE` | 05_Neo4J §7 |
| `PROFILE`, indexes, `allShortestPaths` | 05_Neo4J §8 |
| Challenge scenarios (5 each) | both, §9 |
| Modelling a schema yourself | both homeworks |

The notebook flags these inline at the end of Parts 1 and 2, with links, so the
omissions are visible rather than silent.

## Teaching notes

- **Setup is the risk.** The image build is the only slow step; if the room has
  weak wifi, have students run `docker compose up -d` *before* the session, or
  pre-build on a USB stick. Everything after setup is seconds.
- **Part 3 is the payload.** If you are running short, cut an exercise from
  Parts 1–2 rather than shortening the head-to-head — the comparison is the only
  thing this session does that the separate practices cannot.
- **The datasets differ on purpose** (products vs. movies). Each store gets data
  that suits it, which is the honest setup; the notebook says explicitly to
  compare *query shape*, not numbers.
- **Q2 is the moment.** "How are these two connected?" has a one-line answer in
  Cypher and no real equivalent in MongoDB. If one idea survives the session,
  this is the one worth making it.
- The final discussion offers three prompts; one is enough for 5 minutes.

## Verified

The full session was run end to end before release: both databases start and
pass their healthchecks in about 5 seconds from a cold volume, `load.sh` imports
75 documents and 148 nodes, and every cell in the notebook executes with zero
errors against the live databases.
