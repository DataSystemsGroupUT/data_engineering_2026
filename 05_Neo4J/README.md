# 🕸️ Neo4j Practice: Building a Movie Knowledge Graph
Neo4j is a native **graph database**: instead of tables and rows, it stores *nodes*
connected by *relationships*, each able to carry properties. Relationships are
stored as real pointers between records, so following one is a constant-time hop
rather than a join computed at query time.

<div style="text-align:center"><img src="https://dist.neo4j.com/wp-content/uploads/property_graph_elements.jpg" width="600"></div>

## 🔍 Key Features

- **Property graph model:** data is nodes, relationships, and properties on either.
- **Relationships are first-class:** connections are stored, not derived by joins.
- **Cypher:** a declarative, pattern-matching query language — you draw the shape you want with ASCII art.
- **Index-free adjacency:** traversal cost depends on the neighbourhood you walk, not on total table size.
- **Variable-length and path queries:** "friends of friends", shortest path, and reachability are one-liners.

## 🚀 Why We Use It

Neo4j is ideal for data where the *connections* carry the meaning:
- Recommendations ("people who rated this also rated…").
- Social and collaboration networks, degrees of separation.
- Fraud rings, dependency graphs, supply chains, lineage.
- Knowledge graphs where new relationship types appear as you go.

> **Where this sits next to MongoDB.** MongoDB nests related data *inside* one
> document, which is ideal when you read a whole aggregate at once. Neo4j keeps
> entities separate and makes the *links* queryable in both directions — which is
> what you want when the same entity is reached from many angles and the
> interesting question is how things connect.

## 📘 Table of Contents

* [1. Introduction](#1-introduction)
  * [Learning Objectives](#-learning-objectives)
* [2. Session Agenda (90 Minutes)](#2-session-agenda-90-minutes)
* [3. Environment Setup](#3-environment-setup)
* [4. Neo4j and Cypher: Core Concepts](#4-neo4j-and-cypher-core-concepts)
* [5. Task 1: Load and Explore the Movie Graph](#5-task-1-load-and-explore-the-movie-graph)
* [6. Task 2: Matching Patterns and Filtering](#6-task-2-matching-patterns-and-filtering)
* [7. Task 3: Writing, Updating and Aggregating](#7-task-3-writing-updating-and-aggregating)
* [8. Task 4: Traversals, Paths and Query Plans](#8-task-4-traversals-paths-and-query-plans)
* [9. Challenge Tasks: Real-world Scenarios](#9-challenge-tasks-real-world-scenarios)
* [10. Troubleshooting & Tips](#10-troubleshooting--tips)
* [11. Key Takeaways](#11-key-takeaways)

---

## 1. Introduction

In this session you will set up a **Neo4j environment** using Docker and build a
**movie knowledge graph** — movies, the people who acted in and directed them,
genres, and users who rated them. You will learn to write Cypher patterns,
traverse relationships, and see why some questions are far easier on a graph
than on tables.

### 🎯 Learning Objectives

By the end of this session, you will:

1. Run Neo4j via Docker Compose and use both the Browser UI and `cypher-shell`.
2. Load CSV data into a graph with `LOAD CSV`, `MERGE`, and constraints.
3. Write Cypher patterns to match nodes, relationships, and paths.
4. Filter, project, sort, and aggregate with `WHERE`, `RETURN`, `WITH`, `collect()`.
5. Create and modify data with `CREATE`, `MERGE`, `SET`, `REMOVE`, and `DELETE`.
6. Traverse variable-length paths and compute shortest paths between nodes.
7. Read a query plan with `PROFILE` and speed queries up with indexes.
8. Explain when a graph model beats a relational or document model — and when it does not.

---

## 2. Session Agenda (90 Minutes)

| Duration | Topic | Goal |
| --- | --- | --- |
| 10 min | Introduction & setup | Run Neo4j, open the Browser |
| 10 min | Load sample data | Import the movie graph, inspect the schema |
| 20 min | Pattern matching & filtering | `MATCH`, `WHERE`, projections, relationships |
| 20 min | Writing & aggregating | `MERGE`, `SET`, `DELETE`, `collect()`, `WITH` |
| 15 min | Traversals & query plans | Variable-length paths, shortest path, `PROFILE` |
| 10 min | Challenge tasks | Recommendations and network analysis |
| 5 min | Wrap-up & discussion | When to reach for a graph database |

---

## 3. Environment Setup

### Step 3.1: Project Structure

```
05_Neo4J/
├── compose.yml            # Neo4j + JupyterLab services
├── notebook.Dockerfile    # Jupyter image (neo4j driver + pandas preinstalled)
├── .env.example           # optional overrides (credentials, versions, ports)
├── notebooks/
│   ├── Practice.ipynb     # guided walkthrough (sections 5-8 from Python)
│   └── Homework.ipynb     # graded assignment
├── sample_data/
│   ├── load.cypher        # the import script you will run
│   ├── people.csv         # 60 actors and directors
│   ├── movies.csv         # 40 movies
│   ├── users.csv          # 40 users who rate movies
│   ├── acted_in.csv       # Person -[:ACTED_IN]-> Movie
│   ├── directed.csv       # Person -[:DIRECTED]-> Movie
│   ├── in_genre.csv       # Movie  -[:IN_GENRE]-> Genre
│   ├── rated.csv          # User   -[:RATED]-> Movie
│   └── follows.csv        # User   -[:FOLLOWS]-> User
└── README.md
```

### Step 3.2: Docker Compose File

The environment is already defined in [`compose.yml`](compose.yml): a **neo4j**
service (the database, which bundles its own Browser UI) and a **notebook**
service running JupyterLab with the Neo4j Python driver and pandas already
installed, so you do not have to install anything on your host.

Credentials and image versions come from environment variables with sensible
defaults, so no setup file is required. To override them, copy the example:

```bash
cp .env.example .env
```

**Run the setup:**

```bash
docker compose up -d
```

The first start builds the Jupyter image, so allow a couple of minutes; after
that it is cached. Neo4j itself takes roughly 20–30 seconds to become ready, and
JupyterLab waits for its healthcheck. Check both services are up:

```bash
docker compose ps
```

✅ Access the tools:

- **Neo4j Browser UI:** <http://localhost:7474> — log in with `neo4j` / `password`
  (set by `NEO4J_USER` / `NEO4J_PASSWORD`). Set the connection URL to
  `bolt://localhost:7687` if it is not already filled in.
- **JupyterLab:** <http://localhost:8888> — no token required. Open
  `Practice.ipynb` to work through this session from Python, or
  `Homework.ipynb` for the assignment.
- **Cypher shell (CLI):**

  ```bash
  docker exec -it neo4j cypher-shell -u neo4j -p password
  ```

  Statements in the shell must end with a semicolon. Type `:exit` to leave.

When you are finished, stop everything and discard the data volume:

```bash
docker compose down -v
```

> 💡 **Which interface?** The **Browser** draws results as an actual graph, so
> prefer it while exploring patterns. The **shell** is best for the load script
> and long copy-pasted queries. The **notebooks** keep query and result together,
> which is what you want for the homework. All three talk to the same database.

> 💡 **Prefer to work without Docker for the notebooks?** You can run them on your
> host instead — `pip install neo4j pandas jupyterlab`, then set
> `NEO4J_URI=bolt://localhost:7687`. The notebooks read that variable and fall
> back to `localhost` when it is unset.

---

## 4. Neo4j and Cypher: Core Concepts

| Concept | Description |
| --- | --- |
| **Node** | An entity, e.g. a movie or a person. Drawn `()` in Cypher. |
| **Label** | A node's type, e.g. `:Movie`. A node can have several. |
| **Relationship** | A typed, directed connection between two nodes, e.g. `-[:ACTED_IN]->`. |
| **Property** | A key-value pair on a node *or* a relationship, e.g. `roles`. |
| **Pattern** | ASCII-art shape to match, e.g. `(p:Person)-[:ACTED_IN]->(m:Movie)`. |
| **Traversal** | Following relationships from node to node — the graph equivalent of a join. |
| **Constraint** | A uniqueness/existence rule. A uniqueness constraint also creates an index. |

**The graph you are about to build:**

```
(:Person)-[:ACTED_IN {roles}]->(:Movie)-[:IN_GENRE]->(:Genre)
(:Person)-[:DIRECTED]-------->(:Movie)
(:User)-[:RATED {rating, rated_year}]->(:Movie)
(:User)-[:FOLLOWS {since}]->(:User)
```

> 💡 **Direction matters when writing, usually not when reading.** `ACTED_IN`
> points from person to movie. In a `MATCH` you can ignore direction by writing
> `-[:ACTED_IN]-` instead of `-[:ACTED_IN]->`, which is how the co-actor queries
> below walk *into* a movie and back *out* to other actors.

---

## 5. Task 1: Load and Explore the Movie Graph

> 💡 Sections 5–8 are also available as a runnable notebook —
> [`notebooks/Practice.ipynb`](notebooks/Practice.ipynb) — if you prefer to work
> from Python and keep your results next to the queries.

### Step 5.1: Sample Data

Open [`sample_data/`](sample_data/). The data is split the way graph imports
usually are: one file per **node type**, one file per **relationship type**.

Scroll through a few files and notice three things:

1. **Relationships live in their own files, and carry properties.**
   `acted_in.csv` has a `roles` column — the role belongs to the *connection*
   between a person and a movie, not to either one alone. A relational schema
   would need a junction table; a document store would have to pick one side to
   nest inside.
2. **The same entity is reached from several directions.** A `Movie` is pointed
   at by actors, directors, genres, and user ratings. There is no "owning"
   parent document, which is precisely the case where nesting breaks down.
3. **Genres are nodes, not strings.** Because `Genre` is its own node, "movies
   that share a genre with X" is a two-hop pattern instead of a self-join.

In a relational database this graph would need `person`, `movie`, `user`,
`genre` tables plus four junction tables, and every "how is A connected to B"
question becomes a chain of joins whose length you must know in advance. Here
the connections are stored directly, and a traversal of unknown depth is a
single pattern.

### Step 5.2: Load Data into Neo4j

The import script is [`sample_data/load.cypher`](sample_data/load.cypher). Run it
from the host — the shell reads it on standard input:

```bash
docker exec -i neo4j cypher-shell -u neo4j -p password < sample_data/load.cypher
```

It prints a node count per label when it finishes. The script is **safe to
re-run**: it creates constraints `IF NOT EXISTS` and writes with `MERGE`, so
loading twice does not duplicate anything.

Open the script and note the three things that make a `LOAD CSV` import work:

- **Constraints first.** `CREATE CONSTRAINT … IS UNIQUE` also creates an index,
  which is what makes each `MERGE` a fast lookup instead of a scan per row.
- **Everything arrives as a string.** `toInteger(row.released)` and
  `toFloat(row.budget_musd)` are required, or you get string properties and
  numeric comparisons silently misbehave.
- **`MATCH` both ends, then `MERGE` the relationship.** The relationship files
  reference nodes by id, so each row looks both endpoints up before connecting
  them.

### Step 5.3: Verify and Explore

```bash
docker exec -it neo4j cypher-shell -u neo4j -p password
```

```cypher
// How many nodes of each label?
MATCH (n) RETURN labels(n)[0] AS label, count(*) AS nodes ORDER BY label;
```

You should see **40 Movie, 60 Person, 40 User, 8 Genre**.

```cypher
// How many relationships of each type?
MATCH ()-[r]->() RETURN type(r) AS rel, count(*) AS n ORDER BY rel;
```

You should see **ACTED_IN 198, DIRECTED 44, FOLLOWS 103, IN_GENRE 81, RATED 546**.

```cypher
// Look at one node in full
MATCH (m:Movie) RETURN m LIMIT 1;

// What does the schema look like?
CALL db.schema.visualization();

// Which property keys and relationship types exist?
CALL db.propertyKeys();
CALL db.relationshipTypes();
```

> 💡 Run `CALL db.schema.visualization()` **in the Browser**, not the shell — it
> returns the schema as a picture, which is the whole point of it.

---

## 6. Task 2: Matching Patterns and Filtering

### Basic Matches

```cypher
// Every movie (LIMIT keeps the Browser responsive)
MATCH (m:Movie) RETURN m LIMIT 25;

// Only the properties we care about
MATCH (m:Movie) RETURN m.title, m.released ORDER BY m.released DESC LIMIT 10;

// One specific node, matched by property
MATCH (p:Person {name: "Tom Hanks"}) RETURN p.name, p.born;

// The same thing written with WHERE -- identical meaning
MATCH (p:Person) WHERE p.name = "Tom Hanks" RETURN p;

// Comparison and boolean operators
MATCH (m:Movie) WHERE m.released >= 1990 AND m.released < 2000
RETURN m.title, m.released ORDER BY m.released;

MATCH (m:Movie) WHERE m.runtime > 150 RETURN m.title, m.runtime ORDER BY m.runtime DESC;

// String matching
MATCH (m:Movie) WHERE m.title STARTS WITH "The Matrix" RETURN m.title, m.released;
MATCH (m:Movie) WHERE toLower(m.title) CONTAINS "the" RETURN m.title LIMIT 5;

// IN, and DISTINCT labels
MATCH (p:Person) WHERE p.country IN ["EE", "US"] RETURN p.name, p.country LIMIT 10;
MATCH (n) RETURN DISTINCT labels(n) AS labels;
```

### Matching Relationships

This is where a graph differs from a table. You **draw the pattern** you want:

```cypher
// Which movies did Tom Hanks act in?
MATCH (:Person {name: "Tom Hanks"})-[:ACTED_IN]->(m:Movie)
RETURN m.title, m.released ORDER BY m.released;

// ...and what roles did he play? The property is on the RELATIONSHIP.
MATCH (:Person {name: "Tom Hanks"})-[r:ACTED_IN]->(m:Movie)
RETURN m.title, r.roles ORDER BY m.title;

// Who directed Cloud Atlas?
MATCH (p:Person)-[:DIRECTED]->(:Movie {title: "Cloud Atlas"}) RETURN p.name;

// Any relationship type, by leaving the type out
MATCH (p:Person)-[r]->(m:Movie) RETURN p.name, type(r), m.title LIMIT 10;

// Two hops: Tom Hanks' co-actors. Note the undirected second leg --
// we walk INTO the movie and back OUT to the other actors.
MATCH (:Person {name: "Tom Hanks"})-[:ACTED_IN]->(m:Movie)<-[:ACTED_IN]-(co:Person)
RETURN DISTINCT co.name AS coActor, m.title ORDER BY coActor LIMIT 10;

// Genres of the movies Tom Hanks acted in
MATCH (:Person {name: "Tom Hanks"})-[:ACTED_IN]->(:Movie)-[:IN_GENRE]->(g:Genre)
RETURN DISTINCT g.name ORDER BY g.name;

// People who both acted in AND directed the same movie
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)<-[:DIRECTED]-(p)
RETURN p.name, m.title;

// Negation: movies with no recorded director
MATCH (m:Movie) WHERE NOT (m)<-[:DIRECTED]-() RETURN m.title;

// Optional match: keep movies even when the left side finds nothing,
// like a LEFT JOIN. Missing values come back as null.
MATCH (m:Movie)
OPTIONAL MATCH (m)<-[:DIRECTED]-(d:Person)
RETURN m.title, d.name AS director ORDER BY m.title LIMIT 10;
```

> 💡 **Why no join?** `(p)-[:ACTED_IN]->(m)` follows a stored pointer from the
> person record to the movie record. The relational equivalent is a join against
> an `acted_in` junction table, whose cost grows with the size of that table.
> Here the cost grows with *this person's* number of films.

### Practice Ideas 💡

Try to write these yourself before looking at the solutions.

1. Find all movies released **after 2015**, newest first.
2. List the **roles Keanu Reeves played**, with the movie title.
3. Find every person who **directed more than one** movie.
4. Find the movies that are in **both** the `Action` **and** `Sci-Fi` genres.
5. Find all **users who rated "The Matrix" 5**.

<details>
<summary>💡 Show Solutions</summary>

```cypher
// 1. Movies after 2015
MATCH (m:Movie) WHERE m.released > 2015
RETURN m.title, m.released ORDER BY m.released DESC;

// 2. Keanu's roles -- the role is a relationship property
MATCH (:Person {name: "Keanu Reeves"})-[r:ACTED_IN]->(m:Movie)
RETURN m.title, r.roles ORDER BY m.title;

// 3. Directors with more than one film: aggregate, then filter with WITH
MATCH (p:Person)-[:DIRECTED]->(m:Movie)
WITH p, count(m) AS films
WHERE films > 1
RETURN p.name, films ORDER BY films DESC;

// 4. Two genre hops from the same movie
MATCH (m:Movie)-[:IN_GENRE]->(:Genre {name: "Action"}),
      (m)-[:IN_GENRE]->(:Genre {name: "Sci-Fi"})
RETURN m.title;

// 5. Users who rated The Matrix 5
MATCH (u:User)-[r:RATED]->(:Movie {title: "The Matrix"})
WHERE r.rating = 5
RETURN u.name, r.rated_year ORDER BY u.name;
```

Note in #3 that `WHERE` cannot filter on an aggregate directly — you compute it
with `WITH` first, then filter. `WITH` is Cypher's equivalent of SQL's `HAVING`,
and more generally it pipes one query stage into the next.
</details>

---

## 7. Task 3: Writing, Updating and Aggregating

### Creating and Merging

```cypher
// CREATE always makes a new node -- run it twice and you get two nodes
CREATE (m:Movie {movie_id: 999, title: "A Test Film", released: 2026})
RETURN m;

// MERGE is "get or create": matches if it exists, creates if it does not.
// This is why the loader is safe to re-run.
MERGE (g:Genre {name: "Documentary"}) RETURN g;

// MERGE on the unique key, then set the rest with ON CREATE / ON MATCH
MERGE (p:Person {person_id: 999})
ON CREATE SET p.name = "New Person", p.born = 1990, p.created = true
ON MATCH  SET p.seen_again = true
RETURN p;

// Create a relationship between two existing nodes
MATCH (p:Person {person_id: 999}), (m:Movie {movie_id: 999})
MERGE (p)-[r:ACTED_IN {roles: "The Tester"}]->(m)
RETURN p.name, r.roles, m.title;
```

> ⚠️ `MERGE` on a pattern with several properties matches only if **all** of them
> match, so `MERGE (p:Person {name: "...", born: 1990})` creates a duplicate when
> only the name matches. Merge on the unique key, then `SET` the other properties.

### Updating

```cypher
// SET one property
MATCH (m:Movie {title: "A Test Film"}) SET m.released = 2027 RETURN m;

// SET several at once
MATCH (m:Movie {title: "A Test Film"})
SET m.tagline = "Only a test", m.runtime = 100
RETURN m;

// Arithmetic from the node's own value
MATCH (m:Movie {title: "A Test Film"})
SET m.runtime = m.runtime + 10
RETURN m.title, m.runtime;

// Add a label to existing nodes: everyone who directed something
MATCH (p:Person)-[:DIRECTED]->(:Movie) SET p:Director;
MATCH (p:Director) RETURN count(p) AS directors;

// REMOVE a property (not the same as setting it to null... actually in Neo4j
// setting a property to null DOES remove it -- both of these work)
MATCH (m:Movie {title: "A Test Film"}) REMOVE m.tagline RETURN m;

// REMOVE a label
MATCH (p:Director) REMOVE p:Director;
```

### Deleting

```cypher
// DETACH DELETE removes a node AND its relationships. Plain DELETE on a node
// that still has relationships is an error -- Neo4j will not leave dangling edges.
MATCH (m:Movie {title: "A Test Film"}) DETACH DELETE m;
MATCH (p:Person {person_id: 999}) DETACH DELETE p;
MATCH (g:Genre {name: "Documentary"}) DELETE g;

// Delete just a relationship, keeping both nodes
MATCH (:Person {name: "Tom Hanks"})-[r:ACTED_IN]->(:Movie {title: "Cast Away"})
DELETE r;

// Count before you delete -- deletes cannot be undone
MATCH (u:User) RETURN count(u);
```

> ⚠️ `MATCH (n) DETACH DELETE n` empties the **entire** database. It is the
> fastest way to reset between experiments, and the fastest way to lose your
> work. Reload afterwards with the `load.cypher` command from Step 5.2.

### Aggregating

Cypher aggregates implicitly: anything in `RETURN` that is not inside an
aggregate function becomes the grouping key.

```cypher
// Films per actor -- p.name is the grouping key, count(m) the aggregate
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)
RETURN p.name, count(m) AS films ORDER BY films DESC LIMIT 10;

// collect() gathers values into a list -- the cast of each movie
MATCH (m:Movie)<-[:ACTED_IN]-(a:Person)
RETURN m.title, collect(a.name) AS cast, count(*) AS actors
ORDER BY actors DESC LIMIT 5;

// Numeric aggregates
MATCH (m:Movie)
RETURN count(*) AS movies,
       round(avg(m.runtime), 1) AS avgRuntime,
       min(m.released) AS oldest,
       max(m.released) AS newest;

// Group by a neighbour: movies per genre
MATCH (m:Movie)-[:IN_GENRE]->(g:Genre)
RETURN g.name AS genre, count(m) AS movies ORDER BY movies DESC;

// Aggregate a relationship property: average rating per movie
MATCH (:User)-[r:RATED]->(m:Movie)
RETURN m.title, round(avg(r.rating), 2) AS avgRating, count(r) AS votes
ORDER BY avgRating DESC LIMIT 10;
```

**Chaining with `WITH`.** `WITH` ends one stage and starts the next, which is how
you filter on an aggregate or feed a result into another pattern:

```cypher
// Best-rated movies among those with enough votes
MATCH (:User)-[r:RATED]->(m:Movie)
WITH m, avg(r.rating) AS avgRating, count(r) AS votes
WHERE votes >= 10
RETURN m.title, round(avgRating, 2) AS avgRating, votes
ORDER BY avgRating DESC LIMIT 5;

// Aggregate, then keep traversing from the result
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)
WITH p, count(m) AS films
WHERE films >= 5
MATCH (p)-[:ACTED_IN]->(:Movie)-[:IN_GENRE]->(g:Genre)
RETURN p.name, films, collect(DISTINCT g.name) AS genres
ORDER BY films DESC;
```

| Clause | What it does |
| --- | --- |
| `MATCH` | Finds the pattern. The workhorse — like `FROM` + `JOIN` + `WHERE`. |
| `WHERE` | Filters the current stage. Attaches to `MATCH` or `WITH`. |
| `RETURN` | Projects the result; groups implicitly when aggregating. |
| `WITH` | Pipes one stage into the next. Needed to filter aggregates. |
| `MERGE` | Get-or-create, so imports stay idempotent. |
| `SET` / `REMOVE` | Change properties and labels. |
| `DETACH DELETE` | Delete nodes together with their relationships. |
| `collect()` | Aggregate values into a list. |

---

## 8. Task 4: Traversals, Paths and Query Plans

### Step 8.1: Variable-length paths

The pattern `-[:REL*1..3]-` follows between 1 and 3 hops. This is the thing that
is genuinely awkward in SQL — each extra hop there means another join, so the
depth must be fixed when you write the query.

```cypher
// Actors one hop away from Tom Hanks through a shared film
MATCH (:Person {name: "Tom Hanks"})-[:ACTED_IN*2]-(co:Person)
RETURN DISTINCT co.name LIMIT 10;

// Up to two shared films away -- "co-actors of my co-actors"
MATCH (tom:Person {name: "Tom Hanks"})-[:ACTED_IN*1..4]-(other:Person)
WHERE other <> tom
RETURN DISTINCT other.name LIMIT 10;

// Who does user 1 reach through the FOLLOWS network, within 3 hops?
MATCH (:User {user_id: 1})-[:FOLLOWS*1..3]->(reached:User)
RETURN DISTINCT reached.user_id ORDER BY reached.user_id LIMIT 15;
```

### Step 8.2: Shortest path

```cypher
// How are these two actors connected through films?
MATCH path = shortestPath(
  (a:Person {name: "Tom Hanks"})-[:ACTED_IN*..6]-(b:Person {name: "Keanu Reeves"})
)
RETURN [n IN nodes(path) | coalesce(n.name, n.title)] AS hops, length(path) AS hopCount;
```

The list comprehension turns the path into readable names: `n.name` for people,
`n.title` for movies. Expect a short chain — these two share a film, so the path
is Person → Movie → Person.

```cypher
// Every shortest path, when there are ties
MATCH path = allShortestPaths(
  (a:Person {name: "Tom Hanks"})-[:ACTED_IN*..6]-(b:Person {name: "Hugo Weaving"})
)
RETURN [n IN nodes(path) | coalesce(n.name, n.title)] AS hops;
```

> ⚠️ Always bound a variable-length pattern (`*..6`, not `*`). An unbounded
> traversal on a dense graph can explore an enormous number of paths.

### Step 8.3: Read a query plan with `PROFILE`

`PROFILE` runs the query and reports what it actually did; `EXPLAIN` shows the
plan without running it. The number to watch is **DB Hits** — how many times the
engine touched the store.

```cypher
PROFILE MATCH (m:Movie {title: "The Matrix"}) RETURN m.title;
```

Look at the operator column. With no index on `title` you get:

- `NodeByLabelScan` — every `:Movie` node is read, then a `Filter` discards 39 of them.
- **DB Hits: 81** to return a single row.

### Step 8.4: Add an index and compare

```cypher
CREATE INDEX movie_title IF NOT EXISTS FOR (m:Movie) ON (m.title);
```

Index creation is asynchronous. Wait for it to come online:

```cypher
SHOW INDEXES YIELD name, state, type, labelsOrTypes, properties;
```

Then profile the same query again:

```cypher
PROFILE MATCH (m:Movie {title: "The Matrix"}) RETURN m.title;
```

Now:

- `NodeIndexSeek` instead of `NodeByLabelScan` + `Filter`.
- **DB Hits: 2** instead of 81.

On 40 movies this is microseconds either way. On 40 million it is the difference
between a scan and an instant lookup — and note that the *traversals* were always
fast: an index matters for **finding the starting node**, not for following
relationships once you are there. That is the key performance intuition for
graph databases.

```cypher
// The constraints from load.cypher already created indexes -- look:
SHOW CONSTRAINTS;
SHOW INDEXES YIELD name, type, labelsOrTypes, properties;

// Clean up the one we just made
DROP INDEX movie_title IF EXISTS;
```

> 💡 Indexes are not free: each one costs storage and must be updated on every
> write. Index the properties you look nodes **up** by.

### Practice Ideas 💡

1. Find the shortest `FOLLOWS` path between user 1 and user 20. Does one exist?
2. `PROFILE` the co-actor query and find which operator does the most DB hits.
3. Create an index on `Person.name`, then `PROFILE` a lookup by name before and
   after dropping it.

<details>
<summary>💡 Show Solutions</summary>

```cypher
// 1. Shortest FOLLOWS path. Returns no rows if they are not connected --
//    "no path" is a legitimate answer, not an error.
MATCH path = shortestPath((:User {user_id: 1})-[:FOLLOWS*..6]->(:User {user_id: 20}))
RETURN [n IN nodes(path) | n.user_id] AS hops, length(path) AS hopCount;

// 2. Co-actor query plan -- the expand operators dominate
PROFILE
MATCH (:Person {name: "Tom Hanks"})-[:ACTED_IN]->(m:Movie)<-[:ACTED_IN]-(co:Person)
RETURN DISTINCT co.name;

// 3. Index on Person.name
PROFILE MATCH (p:Person {name: "Meg Ryan"}) RETURN p.born;   // NodeByLabelScan
CREATE INDEX person_name IF NOT EXISTS FOR (p:Person) ON (p.name);
SHOW INDEXES YIELD name, state;                              // wait for ONLINE
PROFILE MATCH (p:Person {name: "Meg Ryan"}) RETURN p.born;   // NodeIndexSeek
DROP INDEX person_name IF EXISTS;
```
</details>

---

## 9. Challenge Tasks: Real-world Scenarios

> 📓 The graded assignment is [`notebooks/Homework.ipynb`](notebooks/Homework.ipynb):
> model a relational schema as a property graph and build it, then query the movie
> graph. Submit the notebook with its outputs saved.

🎯 **Challenge 1: Content-based Recommendation**
> Recommend movies to a *person* based on genre overlap with films they acted in —
> excluding films they were already in. Rank by how many genres are shared.

💡 *Hint:* Walk `Person → Movie → Genre → Movie`, then exclude the start node's own
films with `NOT (…)-[:ACTED_IN]->(rec)`.

<details>
<summary>💡 Show Solution</summary>

```cypher
MATCH (p:Person {name: "Tom Hanks"})-[:ACTED_IN]->(:Movie)-[:IN_GENRE]->(g:Genre)
      <-[:IN_GENRE]-(rec:Movie)
WHERE NOT (p)-[:ACTED_IN]->(rec)
RETURN rec.title, count(DISTINCT g) AS sharedGenres
ORDER BY sharedGenres DESC, rec.title
LIMIT 10;
```

`count(DISTINCT g)` matters: without `DISTINCT` you count every *path*, so a
movie reached through the same genre by several films is counted repeatedly.
</details>

---

🎯 **Challenge 2: Collaborative Filtering**
> For user 3, find movies rated highly (4+) by *other users who rated the same
> movies* — the classic "people like you also liked" query. Require a reasonable
> overlap so the neighbours are actually similar.

<details>
<summary>💡 Show Solution</summary>

```cypher
MATCH (me:User {user_id: 3})-[:RATED]->(m:Movie)<-[:RATED]-(other:User)
WITH me, other, count(m) AS overlap
WHERE overlap >= 3
MATCH (other)-[r:RATED]->(rec:Movie)
WHERE NOT (me)-[:RATED]->(rec) AND r.rating >= 4
RETURN rec.title, count(*) AS endorsements, round(avg(r.rating), 2) AS avgRating
ORDER BY endorsements DESC, avgRating DESC
LIMIT 10;
```

This is three stages piped with `WITH`: find similar users, keep the ones with
enough overlap, then collect what they liked that user 3 has not seen. The same
query in SQL needs a self-join on the ratings table plus a `NOT EXISTS`
subquery.
</details>

---

🎯 **Challenge 3: Degrees of Separation**
> Build a "Bacon number" style report: for one actor, how many other actors sit
> at distance 1, 2, and 3 in the co-acting network?

<details>
<summary>💡 Show Solution</summary>

```cypher
MATCH (start:Person {name: "Tom Hanks"})
MATCH path = shortestPath((start)-[:ACTED_IN*..6]-(other:Person))
WHERE other <> start
WITH other, length(path) / 2 AS degree      // each degree is 2 hops: up to a movie, back down
RETURN degree, count(other) AS actors
ORDER BY degree;
```

The `/ 2` is because one degree of co-acting separation is two relationship hops
(person → movie → person). Dividing turns hop counts into the degree people
actually mean.
</details>

---

🎯 **Challenge 4: Most Influential People**
> Rank people by a simple influence score: how many *distinct* other people they
> have worked with, either as actor or director.

<details>
<summary>💡 Show Solution</summary>

```cypher
MATCH (p:Person)-[:ACTED_IN|DIRECTED]->(m:Movie)<-[:ACTED_IN|DIRECTED]-(other:Person)
WHERE other <> p
RETURN p.name, count(DISTINCT other) AS collaborators, count(DISTINCT m) AS films
ORDER BY collaborators DESC
LIMIT 10;
```

`[:ACTED_IN|DIRECTED]` matches either relationship type in one pattern. This is
degree centrality computed by hand; Neo4j's Graph Data Science library offers
PageRank and community detection for the serious versions.
</details>

---

🎯 **Challenge 5: Genre Co-occurrence**
> Which pairs of genres appear together on the same movie most often?

<details>
<summary>💡 Show Solution</summary>

```cypher
MATCH (g1:Genre)<-[:IN_GENRE]-(m:Movie)-[:IN_GENRE]->(g2:Genre)
WHERE g1.name < g2.name          // each pair once, not twice
RETURN g1.name AS genreA, g2.name AS genreB, count(m) AS movies
ORDER BY movies DESC
LIMIT 10;
```

`g1.name < g2.name` is the standard trick for de-duplicating symmetric pairs:
without it the pattern matches each pair in both directions.
</details>

---

## 10. Troubleshooting & Tips

| Symptom | Cause and fix |
| --- | --- |
| `docker compose up` fails: port already allocated | Something else uses 7474 or 7687. Stop it, or set `NEO4J_HTTP_PORT` / `NEO4J_BOLT_PORT` in `.env`. |
| `platform ... does not match` on Apple Silicon | You have `DOCKER_DEFAULT_PLATFORM=linux/amd64` exported. `unset` it — do **not** add a `platform:` key to compose.yml. |
| Container restarts in a loop | Check `docker compose logs neo4j`. A password under 8 characters makes the server refuse to start. |
| Browser cannot connect | Set the connect URL to `bolt://localhost:7687`. The UI is on 7474 but queries go over Bolt on 7687. |
| `The client is unauthorized` | Credentials are `neo4j` / `password` by default. Changing `NEO4J_PASSWORD` after the first start has no effect — the password is stored in the volume. `docker compose down -v` to reset. |
| `Couldn't load the external resource` on `LOAD CSV` | The path is the one *inside* the container, and `file:///people.csv` resolves against the mounted import directory. Check the volume line in compose.yml. |
| Imported numbers behave like strings | `LOAD CSV` yields strings. Wrap with `toInteger()` / `toFloat()`. |
| `MERGE` created duplicates | You merged on a pattern with several properties. Merge on the unique key, then `SET` the rest. |
| `Cannot delete node, it still has relationships` | Use `DETACH DELETE` instead of `DELETE`. |
| Query hangs or returns far too many rows | An unbounded variable-length pattern (`*`). Bound it (`*..4`) and add `LIMIT`. |
| JupyterLab not reachable on 8888 | Check `docker compose ps`. The image builds on first start — watch `docker compose logs notebook`. Set `JUPYTER_PORT` in `.env` if 8888 is taken. |
| Notebook: `ServiceUnavailable` / cannot connect | Inside Docker the URI is `bolt://neo4j:7687` (set for you). Running on the host instead? Use `bolt://localhost:7687`. |
| Notebook returns empty tables | The graph is not loaded. Run the `load.cypher` command from Step 5.2 on the host. |
| You deleted or mangled the data | `MATCH (n) DETACH DELETE n;` then re-run the load from Step 5.2. |
| Want a completely clean slate | `docker compose down -v` removes the data volume, then `docker compose up -d`. |

**Useful shell and Cypher commands**

```cypher
MATCH (n) RETURN count(n);                  // total nodes
MATCH ()-[r]->() RETURN count(r);           // total relationships
CALL db.labels();                           // all labels
CALL db.relationshipTypes();                // all relationship types
CALL db.propertyKeys();                     // all property keys
CALL db.schema.visualization();             // schema as a graph (use the Browser)
SHOW INDEXES;                               // indexes and their state
SHOW CONSTRAINTS;                           // constraints
MATCH (n) DETACH DELETE n;                  // empty the database
```

In the Browser, `:help` lists the UI commands and `:history` shows past queries.

---

## 11. Key Takeaways

1. **Relationships are data, not derived.** A relationship is stored, typed,
   directed, and can carry properties — so `roles` lives on `ACTED_IN`, where it
   belongs, rather than in a junction table or duplicated into a document.
2. **You query by drawing the pattern.** `(p:Person)-[:ACTED_IN]->(m:Movie)` is
   the shape you want; Cypher finds every occurrence. Multi-hop questions stay
   readable where the SQL equivalent accumulates joins.
3. **Variable-length traversal is the differentiator.** "Within N hops",
   shortest path, and reachability are one-liners whose depth need not be known
   when writing the query — the thing that is genuinely hard in SQL.
4. **`WITH` is how queries compose.** It pipes one stage into the next and is
   what lets you filter on aggregates, like SQL's `HAVING` but general.
5. **Indexes find starting nodes; adjacency does the rest.** `PROFILE` showed
   81 DB hits drop to 2 with an index on the lookup property. Traversal from a
   found node was already fast, which is why graph performance depends on the
   neighbourhood you walk rather than total database size.
6. **Neo4j is a good fit** for densely connected data queried from many
   directions — recommendations, networks, lineage, fraud. It is a poor fit for
   bulk aggregation over columns, where the star schema from session 3 wins, and
   unnecessary when your data really is independent aggregates read whole, where
   MongoDB's single-document reads are simpler.

---

When you are finished, shut the environment down:

```bash
docker compose down -v
```
