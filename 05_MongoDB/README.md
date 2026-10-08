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
  * [Learning Objectives](#learning-objectives)
* [2. Session Agenda (90 Minutes)](#2-session-agenda-90-minutes)
* [3. Environment Setup](#3-environment-setup)
* [4. MongoDB + Mongo Express: Core Concepts](#4-mongodb--mongo-express-core-concepts)
* [5. Task 1: Load and Explore Product Data](#5-task-1-load-and-explore-product-data)
* [6. Task 2: Querying and Filtering Products](#6-task-2-querying-and-filtering-products)
* [7. Task 3: Updating and Aggregating Data](#7-task-3-updating-and-aggregating-data)
* [8. Challenge Tasks: Real-world Scenarios](#8-challenge-tasks-real-world-scenarios)
* [9. Troubleshooting & Tips](#9-troubleshooting--tips)
* [10. Key Takeaways](#10-key-takeaways)

---

## 1. Introduction

In this session, you’ll set up a **MongoDB environment** using Docker and work with a simple **product catalog database**. You’ll learn to insert, query, and update documents — building practical experience for real-world data management.

### 🎯 Learning Objectives

By the end of this session, you will:

1. Run MongoDB and Mongo Express via Docker Compose.
2. Insert and explore JSON data into MongoDB.
3. Perform CRUD (Create, Read, Update, Delete) operations.
4. Use aggregation and filtering for insights.
5. Understand document structure and schema flexibility.

---

## 2. Session Agenda (90 Minutes)

| Duration | Topic                                  | Goal                                      |
| -------- | -------------------------------------- | ----------------------------------------- |
| 10 min   | Introduction & Setup                   | Run MongoDB and UI                        |
| 15 min   | Load Sample Data                       | Insert product JSON                       |
| 20 min   | Querying Data                          | Use filters, projections, and conditions  |
| 20 min   | Updating & Aggregating                 | Learn updates and analysis queries        |
| 15 min   | Challenge Tasks                        | Apply knowledge in realistic scenarios    |
| 10 min   | Wrap-up & Discussion                   | Review key learnings                      |

---

## 3. Environment Setup

### Step 3.1: Project Structure

```
05_MongoDB/
├── compose.yml          # MongoDB + Mongo Express services
├── .env.example         # optional overrides (credentials, versions, ports)
├── sample_data/
│   └── products.json    # the product catalog you will import
└── README.md
```

### Step 3.2: Docker Compose File

The environment is already defined in [`compose.yml`](compose.yml): a **mongodb**
service (the database) and a **mongo-express** service (a web UI for browsing it).

Credentials and image versions come from environment variables with sensible
defaults, so no setup file is required. To override them, copy the example:

```bash
cp .env.example .env
```

**Run the setup:**

```bash
docker compose up -d
```

Mongo Express waits for MongoDB to pass its healthcheck, so the first start
takes around 20 seconds. Check both services are up:

```bash
docker compose ps
```

✅ Access the tools:

- **Mongo Express UI:** <http://localhost:8081> — browser login `admin` / `pass`
  (set by `ME_USER` / `ME_PASSWORD`; these are *not* the database credentials)
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

### Step 5.1: Sample Data

Open [`sample_data/products.json`](sample_data/products.json). It holds a small
product catalog — three documents, one per product.

Look at the `attributes` field in each one. A footwear product has `size`,
`weight` and `color`; a laptop has `processor`, `ram` and `storage`; the software
product has a `platform` **array**. Every document lives in the same collection
even though no two share the same shape.

This is the point of a document store: in a relational database these three
products would need either three separate tables or one wide table full of
`NULL`s. Here, each document carries only the fields that apply to it.

### Step 5.2: Load Data into MongoDB

```bash
docker exec -it mongodb mongoimport   --username admin   --password password   --authenticationDatabase admin   --db shop   --collection products   --file /sample_data/products.json   --jsonArray
```

### Step 5.3: Verify Data

```bash
docker exec -it mongodb mongosh -u admin -p password --authenticationDatabase admin

use shop
db.products.find().pretty()
```

---

## 6. Task 2: Querying and Filtering Products

### Basic Queries

```js
use shop

// Show all products
db.products.find()

// Show products in category 'Electronics'
db.products.find({ category: "Electronics" })

// Only show name and price fields
db.products.find({}, { name: 1, price: 1 })

// Filter products under 100 EUR
db.products.find({ price: { $lt: 100 } })
```

### Fun Practice Ideas 💡

1. Find all products that are **not software**.
2. List all **products with color black**.
3. Find all products with **RAM attribute** (hint: use `$exists`).

---

## 7. Task 3: Updating and Aggregating Data

### Updates

```js
use shop

// Add a new field: stock count
db.products.updateMany({}, { $set: { stock: 50 } })

// Update one product's price
db.products.updateOne({ name: "Running Shoes" }, { $set: { price: 79.99 } })

// Rename a field
db.products.updateMany({}, { $rename: { "attributes.weight": "attributes.item_weight" } })
```

### Deletions

```js
// Remove one product
db.products.deleteOne({ name: "Photo Editor Pro" })

// Remove all software products
db.products.deleteMany({ category: "Software" })
```

### Aggregations

```js
// Average price by category
db.products.aggregate([
  { $group: { _id: "$category", avgPrice: { $avg: "$price" } } }
])

// Count total products by category
db.products.aggregate([
  { $group: { _id: "$category", count: { $sum: 1 } } }
])
```

---


## 8. Challenge Tasks: Real-world Scenarios

🎯 **Challenge 1: Discount Campaign**
> Add a `discounted_price` field that applies a 10% discount to products over €100.

💡 *Hint:* Use `$set` with `$multiply` in an **aggregation pipeline update** —
pass an array as the second argument to `updateMany()`. (A plain
`$mul` cannot do this: it multiplies by a constant and cannot read
another field's value.)

<details>
<summary>💡 Show Solution</summary>

```javascript
use shop

db.products.updateMany(
  { price: { $gt: 100 } },
  [
    { 
      $set: { 
        discounted_price: { 
          $multiply: [ "$price", 0.9 ] 
        } 
      } 
    }
  ]
)
```
</details>

---

🎯 **Challenge 2: Stock Management**
> Decrease stock by 1 when a product is sold.

💡 *Hint:* Use `$inc: { stock: -1 }`.

<details>
<summary>💡 Show Solution</summary>

```javascript
use shop

// Initialize stock for demo
db.products.updateMany({}, { $set: { stock: 10 } })

// Simulate a sale
db.products.updateOne(
  { name: "Laptop" },
  { $inc: { stock: -1 } }
)
```
</details>

---

🎯 **Challenge 3: Product Search**
> Find all products where the name includes the word *“Pro”* (case-insensitive).

💡 *Hint:* Use regex — `{ name: { $regex: /pro/i } }`.

<details>
<summary>💡 Show Solution</summary>

```javascript
use shop

db.products.find(
  { name: { $regex: /pro/i } },
  { name: 1, category: 1, price: 1, _id: 0 }
)
```
</details>

---

Thank you! 
