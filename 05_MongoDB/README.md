# 🧱 MongoDB Practice: Building a Product Catalog Database
MongoDB is a modern, document-oriented NoSQL database designed for flexibility and scalability.
Unlike traditional relational databases that store data in tables and rows, MongoDB stores information in JSON-like documents — making it easier to handle unstructured or evolving data.

![MongoDB Intro](https://studio3t.com/wp-content/uploads/2020/09/introduction-to-mongodb.png)

## 🔍 Key Features

- Document-based storage: Data is stored as rich, nested documents ({ key: value }), making it intuitive and closer to real-world objects.
- Schema flexibility: No fixed table structure — fields can differ between documents.
- High scalability: Supports horizontal scaling with sharding and replication.
- Powerful querying: Built-in support for complex filters, aggregations, and indexing.
- Developer-friendly: Works naturally with modern programming languages and JSON APIs.

## 🚀 Why We Use It

MongoDB is ideal for applications that:
- Need to handle rapidly changing data models (e.g., user profiles, product catalogs).
- Require fast reads and writes at scale.
- Store hierarchical or nested data that fits naturally into documents.
- Benefit from quick prototyping and flexible schema evolution.

## 📘 Table of Contents

* [1. Introduction](#1-introduction)
  * [Learning Objectives](#-learning-objectives)
* [2. Session Agenda (90 Minutes)](#2-session-agenda-90-minutes)
* [3. Environment Setup](#3-environment-setup)
* [4. MongoDB + Mongo Express: Core Concepts](#4-mongodb--mongo-express-core-concepts)
* [5. Task 1: Load and Explore Product Data](#5-task-1-load-and-explore-product-data)
* [6. Task 2: Querying and Filtering Products](#6-task-2-querying-and-filtering-products)
* [7. Task 3: Updating and Aggregating Data](#7-task-3-updating-and-aggregating-data)
* [8. Task 4: Indexes and Query Plans](#8-task-4-indexes-and-query-plans)
* [9. Challenge Tasks: Real-world Scenarios](#9-challenge-tasks-real-world-scenarios)
* [10. Troubleshooting & Tips](#10-troubleshooting--tips)
* [11. Key Takeaways](#11-key-takeaways)

---

## 1. Introduction

In this session, you’ll set up a **MongoDB environment** using Docker and work with a simple **product catalog database**. You’ll learn to insert, query, and update documents — building practical experience for real-world data management.

### 🎯 Learning Objectives

By the end of this session, you will:

1. Run MongoDB and Mongo Express via Docker Compose.
2. Import JSON data into MongoDB and explore a collection.
3. Perform CRUD (Create, Read, Update, Delete) operations.
4. Query nested subdocuments and array fields using dot notation.
5. Summarise data with aggregation pipelines (`$match`, `$group`, `$unwind`).
6. Read a query plan with `explain()` and speed queries up with indexes.
7. Explain what schema flexibility buys you — and what it costs.

---

## 2. Session Agenda (90 Minutes)

| Duration | Topic | Goal |
| --- | --- | --- |
| 10 min | Introduction & setup | Run MongoDB and the web UI |
| 10 min | Load sample data | Import the product catalog, explore documents |
| 20 min | Querying & filtering | Operators, dot notation, array queries |
| 20 min | Updating & aggregating | Update operators and aggregation pipelines |
| 15 min | Indexes & query plans | Read `explain()`, make a query use an index |
| 10 min | Challenge tasks | Apply it in realistic scenarios |
| 5 min | Wrap-up & discussion | When to use a document store — and when not to |

---

## 3. Environment Setup

### Step 3.1: Project Structure

```
05_MongoDB/
├── compose.yml          # MongoDB + Mongo Express + JupyterLab services
├── notebook.Dockerfile  # Jupyter image (pymongo + pandas preinstalled)
├── .env.example         # optional overrides (credentials, versions, ports)
├── notebooks/
│   ├── Practice.ipynb   # guided walkthrough (sections 5-8 from Python)
│   └── Homework.ipynb   # graded assignment
├── sample_data/
│   └── products.json    # the product catalog you will import
└── README.md
```

### Step 3.2: Docker Compose File

The environment is already defined in [`compose.yml`](compose.yml): a **mongodb**
service (the database), a **mongo-express** service (a web UI for browsing it),
and a **notebook** service running JupyterLab with `pymongo` and pandas already
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

Mongo Express and JupyterLab both wait for MongoDB to pass its healthcheck, so
the first start takes around 20 seconds — plus a couple of minutes the very first
time, while the Jupyter image builds. Check the services are up:

```bash
docker compose ps
```

✅ Access the tools:

- **Mongo Express UI:** <http://localhost:8081> — browser login `admin` / `pass`
  (set by `ME_USER` / `ME_PASSWORD`; these are *not* the database credentials)
- **JupyterLab:** <http://localhost:8889> — no token required. Open
  `Practice.ipynb` to work through this session from Python, or
  `Homework.ipynb` for the assignment. (Port 8889, so it does not clash with the
  Neo4j session's 8888.)
- **MongoDB shell (CLI):**

  ```bash
  docker exec -it mongodb mongosh -u admin -p password --authenticationDatabase admin
  ```

  `--authenticationDatabase admin` is required because the root user is created
  in the `admin` database, not in `shop`.

When you are finished, stop everything and discard the data volume:

```bash
docker compose down -v
```

---

## 4. MongoDB + Mongo Express: Core Concepts

| Concept          | Description                                                                 |
| ---------------- | --------------------------------------------------------------------------- |
| **Database**     | A logical grouping of collections.                                          |
| **Collection**   | A group of JSON-like documents (similar to a table in SQL).                 |
| **Document**     | A record stored in BSON (Binary JSON) format.                              |
| **CRUD**         | Basic operations: Create, Read, Update, Delete.                             |
| **Aggregation**  | Powerful way to process and analyze data via pipeline stages.               |
| **Schema-less**  | Documents can have flexible fields — great for semi-structured data.        |

---

## 5. Task 1: Load and Explore Product Data

> 💡 Sections 5–8 are also available as a runnable notebook —
> [`notebooks/Practice.ipynb`](notebooks/Practice.ipynb) — if you prefer to work
> from Python and keep your results next to the queries. The operators are
> identical; only the surrounding syntax differs (`{ price: { $lt: 50 } }` in the
> shell becomes `{'price': {'$lt': 50}}` in Python).

### Step 5.1: Sample Data

Open [`sample_data/products.json`](sample_data/products.json). It holds a product
catalog of **75 documents** across five categories (Footwear, Electronics,
Software, Home, Outdoor).

Scroll through a few documents and notice three things:

1. **`attributes` has a different shape per category.** A shoe has `size`,
   `material` and `color`; a laptop has `processor`, `ram` and `storage`; a
   software product has a `platform` array and `license_seats`.
2. **Some fields are simply absent.** Only some products carry `discontinued`
   or a nested `supplier` subdocument. There is no `NULL` — the field is just
   not there, and queries can ask which documents have it.
3. **Some fields hold arrays.** `tags` and `ratings` store several values in a
   single field, and MongoDB can query and aggregate *inside* them.

In a relational database this catalog would need either one wide table full of
`NULL`s, five category tables, or an EAV side-table plus a join for every
attribute lookup. Here all 75 products live in one collection, and each
document carries exactly the fields that apply to it.

### Step 5.2: Load Data into MongoDB

```bash
docker exec -it mongodb mongoimport   --username admin   --password password   --authenticationDatabase admin   --db shop   --collection products   --file /sample_data/products.json   --jsonArray
```

### Step 5.3: Verify and Explore

```bash
docker exec -it mongodb mongosh -u admin -p password --authenticationDatabase admin
```

```js
use shop

// How many documents landed?
db.products.countDocuments()          // 75

// Look at one document in full
db.products.findOne()

// What categories exist, and how many products in each?
db.products.aggregate([
  { $group: { _id: "$category", n: { $sum: 1 } } },
  { $sort: { n: -1 } }
])

// Which documents carry the optional `supplier` field?
db.products.countDocuments({ supplier: { $exists: true } })
```

> 💡 `find()` prints only the first 20 documents and then shows a
> `Type "it" for more` prompt. Type `it` to page through the rest.

---

## 6. Task 2: Querying and Filtering Products

### Basic Queries

```js
use shop

// Show all products (paged -- type `it` for the next page)
db.products.find()

// Products in one category
db.products.find({ category: "Electronics" })

// Only the fields we care about; _id: 0 hides the default id
db.products.find({}, { name: 1, price: 1, _id: 0 })

// Comparison operators
db.products.find({ price: { $lt: 50 } })                 // under 50 EUR
db.products.find({ price: { $gte: 100, $lte: 300 } })    // a price band
db.products.find({ category: { $ne: "Software" } })      // not software

// Sort and limit: the five most expensive products
db.products.find({}, { name: 1, price: 1, _id: 0 }).sort({ price: -1 }).limit(5)
```

### Querying Nested Fields and Arrays

This is where a document store differs from a table. Use **dot notation** to
reach into subdocuments, and match arrays by *membership*:

```js
// Dot notation into the attributes subdocument
db.products.find({ "attributes.color": "black" }, { name: 1, _id: 0 })

// Dot notation two levels deep, into the optional supplier subdocument
db.products.find({ "supplier.country": "EE" }, { name: 1, supplier: 1, _id: 0 })

// Array membership: `tags` is an array, but you match it like a single value
db.products.find({ tags: "sale" }, { name: 1, tags: 1, _id: 0 })

// Match documents whose tags contain ALL of these
db.products.find({ tags: { $all: ["sale", "popular"] } }, { name: 1, tags: 1, _id: 0 })

// Match any of several values
db.products.find({ category: { $in: ["Home", "Outdoor"] } }, { name: 1, category: 1, _id: 0 })

// Which documents even HAVE an optional field?
db.products.find({ discontinued: { $exists: true } }, { name: 1, discontinued: 1, _id: 0 })

// Array size
db.products.find({ ratings: { $size: 0 } }, { name: 1, _id: 0 })   // never rated
```

> 💡 **Why no join?** `attributes` and `supplier` are stored *inside* the product
> document, so reading a product reads its attributes in the same operation. The
> relational equivalent would be a join against an attributes table.

### Practice Ideas 💡

Try to write these yourself before looking at the solutions.

1. Find all products that are **out of stock** (`stock` is 0).
2. List all **Footwear in size 42**.
3. Find every product **tagged `premium` priced over 200 EUR**.
4. Find all products that run on **Linux** (hint: `attributes.platform` is an array).
5. Find products with **no `supplier` field** at all.

<details>
<summary>💡 Show Solutions</summary>

```js
// 1. Out of stock
db.products.find({ stock: 0 }, { name: 1, stock: 1, _id: 0 })

// 2. Footwear in size 42
db.products.find(
  { category: "Footwear", "attributes.size": 42 },
  { name: 1, "attributes.size": 1, _id: 0 }
)

// 3. Premium and over 200 EUR
db.products.find(
  { tags: "premium", price: { $gt: 200 } },
  { name: 1, price: 1, tags: 1, _id: 0 }
)

// 4. Runs on Linux -- array membership, same syntax as a scalar
db.products.find(
  { "attributes.platform": "Linux" },
  { name: 1, "attributes.platform": 1, _id: 0 }
)

// 5. No supplier field
db.products.find({ supplier: { $exists: false } }, { name: 1, _id: 0 })
```
</details>

---

## 7. Task 3: Updating and Aggregating Data

### Updates

```js
use shop

// Add a field to every document that does not have it
db.products.updateMany({ discontinued: { $exists: false } }, { $set: { discontinued: false } })

// Update one document
db.products.updateOne({ name: "Laptop" }, { $set: { price: 999.0 } })

// $inc adds to a number (negative to subtract)
db.products.updateOne({ name: "Laptop" }, { $inc: { stock: -1 } })

// $push appends to an array; $addToSet appends only if not already present
db.products.updateOne({ name: "Laptop" }, { $push: { ratings: 4.7 } })
db.products.updateOne({ name: "Laptop" }, { $addToSet: { tags: "popular" } })

// $pull removes matching values from an array
db.products.updateMany({}, { $pull: { tags: "clearance" } })

// $unset removes a field entirely -- not the same as setting it to null
db.products.updateMany({}, { $unset: { discontinued: "" } })
```

> ⚠️ `updateMany({}, ...)` with an empty filter touches **every** document.
> Always run the filter as a `find()` first to see what you are about to change.

### Deletions

```js
// Remove the documents that are out of stock AND discontinued
db.products.deleteMany({ stock: 0, discontinued: true })

// countDocuments first -- deletes cannot be undone
db.products.countDocuments({ category: "Software" })
db.products.deleteMany({ category: "Software" })
```

> If you delete too much, reload from scratch: `db.products.drop()` and re-run
> the `mongoimport` from Step 5.2.

### Aggregations

An aggregation is a **pipeline**: each stage takes the documents from the
previous stage and passes its output to the next.

```js
// Products and average price per category, most expensive category first
db.products.aggregate([
  { $group: {
      _id: "$category",
      products: { $sum: 1 },
      avgPrice: { $avg: "$price" },
      maxPrice: { $max: "$price" }
  } },
  { $project: {
      _id: 0,
      category: "$_id",
      products: 1,
      avgPrice: { $round: ["$avgPrice", 2] },
      maxPrice: 1
  } },
  { $sort: { avgPrice: -1 } }
])

// $match first, then group -- filter early so later stages see fewer documents
db.products.aggregate([
  { $match: { stock: { $gt: 0 } } },
  { $group: { _id: "$brand", inStock: { $sum: "$stock" } } },
  { $sort: { inStock: -1 } },
  { $limit: 5 }
])
```

**Working with arrays.** `$unwind` turns one document with an N-element array
into N documents — which is how you group *by* array values:

```js
// Most common tags across the catalog
db.products.aggregate([
  { $unwind: "$tags" },
  { $group: { _id: "$tags", products: { $sum: 1 } } },
  { $sort: { products: -1 } }
])

// Average rating per product, computed from the ratings array
db.products.aggregate([
  { $match: { "ratings.0": { $exists: true } } },     // skip never-rated products
  { $project: {
      _id: 0,
      name: 1,
      reviews: { $size: "$ratings" },
      avgRating: { $round: [{ $avg: "$ratings" }, 2] }
  } },
  { $sort: { avgRating: -1 } },
  { $limit: 10 }
])

// Group by a nested field: how many products per supplier country
db.products.aggregate([
  { $match: { supplier: { $exists: true } } },
  { $group: { _id: "$supplier.country", products: { $sum: 1 } } },
  { $sort: { products: -1 } }
])
```

| Stage | What it does |
| --- | --- |
| `$match` | Filters documents, like `find()`. Put it first where possible. |
| `$group` | Groups by `_id` and computes accumulators (`$sum`, `$avg`, `$max`). |
| `$project` | Chooses, renames and computes fields. |
| `$sort` / `$limit` | Orders and truncates the result. |
| `$unwind` | Expands an array field into one document per element. |

---

## 8. Task 4: Indexes and Query Plans

MongoDB can answer any query without an index by reading every document — a
**collection scan**. That works on 75 documents and falls over on 75 million.
`explain()` shows which one you are getting.

### Step 8.1: Look at a query with no index

```js
use shop

db.products.find({ category: "Electronics" }).explain("executionStats")
```

Find these two values in the output:

- `winningPlan.stage` → **`COLLSCAN`** — a collection scan.
- `executionStats.totalDocsExamined` → **75** — every document was read to
  return 24.

### Step 8.2: Add an index and compare

```js
db.products.createIndex({ category: 1 })        // 1 = ascending, -1 = descending

db.products.find({ category: "Electronics" }).explain("executionStats")
```

Now:

- `winningPlan.stage` → **`IXSCAN`** (inside a `FETCH`) — an index scan.
- `totalDocsExamined` → **24** — only the matching documents were read.

The collection went from reading 75 documents to reading 24. On a collection of
millions, that is the difference between a scan and an instant lookup.

### Step 8.3: Compound indexes serve sorts too

A sort with no usable index must load the results and sort them in memory (a
`SORT` stage). An index that already stores the values in order removes it:

```js
// Before: this query plan contains a SORT stage
db.products.find({ category: "Electronics" }).sort({ price: -1 }).explain()

db.products.createIndex({ category: 1, price: -1 })

// After: no SORT stage -- the index supplies the order
db.products.find({ category: "Electronics" }).sort({ price: -1 }).explain()
```

**Field order matters.** A `{ category: 1, price: -1 }` index can serve a query
on `category` alone, or on `category` *and* `price` — but not one on `price`
alone. An index is usable left-to-right, like a phone book sorted by surname
then first name.

### Step 8.4: Inspect and clean up

```js
db.products.getIndexes()                         // every index on the collection
db.products.dropIndex("category_1")              // drop by name
```

> 💡 Indexes are not free: each one consumes storage and must be updated on
> every insert and update. Index the fields you actually filter and sort on.

### Practice Ideas 💡

1. Create an index on `price` and confirm `find({ price: { $lt: 50 } })` uses it.
2. `_id` is indexed automatically. Check with `getIndexes()`, then explain
   `findOne({ _id: ... })` using an id from your data.
3. Create an index on the **array** field `tags` and explain
   `find({ tags: "sale" })`. MongoDB calls this a multikey index — look for
   `isMultiKey: true` in the plan.

---

## 9. Challenge Tasks: Real-world Scenarios

> 📓 The graded assignment is [`notebooks/Homework.ipynb`](notebooks/Homework.ipynb):
> model a relational schema as documents and build it, then query the catalog.
> Submit the notebook with its outputs saved.

🎯 **Challenge 1: Discount Campaign**
> Add a `discounted_price` field holding a 10% discount, for products over €100.

💡 *Hint:* Use `$set` with `$multiply` in an **aggregation pipeline update** —
pass an array as the second argument to `updateMany()`. (A plain `$mul` cannot
do this: it multiplies by a constant and cannot read another field's value.)

<details>
<summary>💡 Show Solution</summary>

```js
use shop

db.products.updateMany(
  { price: { $gt: 100 } },
  [
    { $set: { discounted_price: { $round: [{ $multiply: ["$price", 0.9] }, 2] } } }
  ]
)

// Check it
db.products.find(
  { discounted_price: { $exists: true } },
  { name: 1, price: 1, discounted_price: 1, _id: 0 }
).limit(5)
```
</details>

---

🎯 **Challenge 2: Restock Report**
> List every out-of-stock product that is **not** discontinued, with its
> category and supplier country where one is recorded.

<details>
<summary>💡 Show Solution</summary>

```js
use shop

db.products.find(
  { stock: 0, discontinued: { $ne: true } },
  { name: 1, category: 1, price: 1, "supplier.country": 1, _id: 0 }
).sort({ category: 1 })
```

`discontinued: { $ne: true }` is deliberate: it matches documents where the
field is `false` **and** documents where the field is missing entirely.
`discontinued: false` alone would miss the latter.
</details>

---

🎯 **Challenge 3: Product Search**
> Find all products whose name contains *"Pro"* (case-insensitive).

💡 *Hint:* Use a regex — `{ name: { $regex: /pro/i } }`.

<details>
<summary>💡 Show Solution</summary>

```js
use shop

db.products.find(
  { name: { $regex: /pro/i } },
  { name: 1, category: 1, price: 1, _id: 0 }
)
```

Note that a leading-wildcard regex like this **cannot use a normal index** — it
has to scan. For real text search, MongoDB offers a dedicated text index:

```js
db.products.createIndex({ name: "text" })
db.products.find({ $text: { $search: "pro" } }, { name: 1, _id: 0 })
```
</details>

---

🎯 **Challenge 4: Best-Rated per Category**
> For each category, report the number of products, the average price, and the
> best average rating achieved by any product in it.

<details>
<summary>💡 Show Solution</summary>

```js
use shop

db.products.aggregate([
  { $project: {
      category: 1,
      price: 1,
      avgRating: { $avg: "$ratings" }      // null when ratings is empty
  } },
  { $group: {
      _id: "$category",
      products: { $sum: 1 },
      avgPrice: { $avg: "$price" },
      bestRating: { $max: "$avgRating" }
  } },
  { $project: {
      _id: 0,
      category: "$_id",
      products: 1,
      avgPrice: { $round: ["$avgPrice", 2] },
      bestRating: { $round: ["$bestRating", 2] }
  } },
  { $sort: { avgPrice: -1 } }
])
```
</details>

---

🎯 **Challenge 5: Tag Co-occurrence**
> Which tag appears most often among products priced over €500?

<details>
<summary>💡 Show Solution</summary>

```js
use shop

db.products.aggregate([
  { $match: { price: { $gt: 500 } } },
  { $unwind: "$tags" },
  { $group: { _id: "$tags", products: { $sum: 1 } } },
  { $sort: { products: -1 } }
])
```
</details>

---

## 10. Troubleshooting & Tips

| Symptom | Cause and fix |
| --- | --- |
| `docker compose up` fails: port already allocated | Something else uses 27017 or 8081. Stop it, or set `MONGO_PORT` / `MONGO_EXPRESS_PORT` in `.env`. |
| `mongo-express` shows "Waiting for mongodb:27017..." | Normal on first start; it waits for the healthcheck (~20s). Check with `docker compose ps`. |
| Mongo Express asks for a login | Browser login is `admin` / `pass` (`ME_USER` / `ME_PASSWORD`), *not* the database credentials. |
| `Authentication failed` in mongosh | The `--authenticationDatabase admin` flag is required; the root user lives in `admin`, not `shop`. |
| `mongoimport: file not found` | The path is the one *inside* the container: `/sample_data/products.json`. |
| Collection is empty after import | You imported into a different database. `use shop` then `db.products.countDocuments()`. |
| `find()` prints only 20 documents | That is the shell's page size. Type `it` for the next page. |
| JupyterLab not reachable on 8889 | Check `docker compose ps`. The image builds on first start — watch `docker compose logs notebook`. Set `JUPYTER_PORT` in `.env` if 8889 is taken. |
| Notebook: `ServerSelectionTimeoutError` | Inside Docker the URI uses host `mongodb` (set for you). Running on the host instead? Use `mongodb://admin:password@localhost:27017/?authSource=admin`. |
| Notebook returns empty tables | The catalog is not imported. Run the `mongoimport` from Step 5.2 on the host. |
| You deleted or mangled the data | `db.products.drop()`, then re-run the `mongoimport` from Step 5.2. |
| Want a completely clean slate | `docker compose down -v` removes the data volume, then `docker compose up -d`. |

**Useful shell commands**

```js
show dbs                      // list databases
show collections              // list collections in the current database
db.products.countDocuments()  // count documents
db.products.findOne()         // one document, fully expanded
db.products.drop()            // delete the collection
db.stats()                    // database size and counts
```

---

## 11. Key Takeaways

1. **Documents, not rows.** A document holds nested objects and arrays, so data
   that belongs together is stored and read together — no join required.
2. **Flexible schema is not "no schema".** The three different `attributes`
   shapes are convenient, but *your application* now owns the contract that
   used to be enforced by `CREATE TABLE`. Queries must cope with missing
   fields, which is why `$exists` and `$ne` matter.
3. **Query operators compose.** `$lt`, `$in`, `$all`, `$exists` and `$size`
   combine with dot notation to reach into nested and array fields.
4. **Aggregation is a pipeline.** Stages pass documents along; `$match` early,
   `$group` to summarise, `$unwind` to work across arrays.
5. **Indexes decide whether a query scales.** `explain()` tells you whether you
   got a `COLLSCAN` or an `IXSCAN`, and compound indexes can also serve sorts.
6. **MongoDB is a good fit** for evolving, hierarchical, read-heavy data — and a
   poor fit when you need multi-table joins and strong relational constraints.
   The star schema from session 3 is still the right tool for analytics.

---

When you are finished, shut the environment down:

```bash
docker compose down -v
```
