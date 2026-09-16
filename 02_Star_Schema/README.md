# Practice 3: Dimensional Modeling and Star Schemas

Build and query a small sales warehouse in PostgreSQL. Starting from supermarket
business questions, you will complete a star schema, load purchase lines, and
check that your analytical queries answer the questions you intended to ask.

The lecture introduces dimensional modeling. This practical focuses on applying
those concepts; customer history and broader warehouse architecture are optional
extensions.

## Learning outcomes

By the end of this practice, you should be able to:

- State the grain of a fact table and distinguish it from a query's grouping level.
- Connect facts to dimensions using warehouse keys while retaining source identifiers.
- Calculate revenue, basket size, and average selling price at the correct grain.
- Verify that joins and aggregations preserve the meaning and totals of the data.

**Prerequisites:** the Docker and PostgreSQL setup from earlier practices, basic
SQL joins and `GROUP BY`, and the lecture's introduction to facts, dimensions,
grain, and surrogate keys. A subquery or common table expression (`WITH`) will be
useful for the basket exercise.

## Session overview — 95 minutes

| Activity | Minutes | Deliverable |
| --- | ---: | --- |
| Business questions and scope | 5 | Definitions of revenue and basket size |
| Design worksheet in pairs | 15 | Grain, keys, dimensions, and facts |
| Complete the schema and load the data | 20 | Working star schema |
| Four analytical exercises | 30 | Queries with explained results |
| Validation and one misleading query | 15 | Reconciled totals and a corrected calculation |
| Discussion and connection to the course project | 10 | A justified modeling decision |
| **Total** | **95** | |

Optional work is outside this time budget. Keep your worksheet and SQL answers
for the discussion. Use Moodle for submission requirements, if assigned.

## 1. Business questions and scope

A supermarket analyst wants to know:

1. How does revenue vary by store and month, and which days contribute to it?
2. Which categories and products generate the most revenue?
3. How many units does a customer buy in an average completed purchase?
4. What is the average price paid per unit of each product?

For this exercise, **revenue means the sum of line sales amounts** and **basket
size means units per purchase**, not distinct products or the number of lines.
All prices are EUR, quantities are whole units, and every purchase is completed.
Returns, discounts, and tax calculations are excluded, so a line's sales amount
is quantity multiplied by its price at the time of purchase.

Use four dimensions: **Date, Product, Store, and Customer**. Every purchase has
one date, store, and customer identifier. A shopper who is not identified uses a
reserved unknown-customer record. Supplier and payment analysis are outside the
required model.

The synthetic source has globally unique purchase IDs within one source system.
A product can appear on several lines of a purchase. Prices can differ between
purchases. Customer attributes are static in the required exercise; do not run
customer-history updates against these tables.

## 2. Design worksheet

Work in pairs before opening the reference solution. Record short answers:

| Decision | Questions to answer |
| --- | --- |
| Business process | What event are we measuring? What is outside the model? |
| Grain | Complete: “One fact row represents …”. Can a repeated product occur in a purchase? |
| Dimensions | Which attributes will label, filter, and group each business question? |
| Facts | Which numeric values do we retain? Which can we sum meaningfully? |
| Keys | How do we distinguish a purchase, its line, and the warehouse row? |
| Customer identity | Why retain a source `CustomerID` as well as a warehouse `CustomerKey`? |

Discuss why `(PurchaseID, ProductID)` and `(CustomerID, SaleDate)` are insufficient
identifiers for a purchase line. Agree on your answer with the lecturer before
completing the schema.

The source-to-target mapping used by the supplied loader is:

| Source value | Warehouse representation |
| --- | --- |
| Purchase ID and line number | Retained in the fact table to identify the source line |
| Sale date | Lookup in `DimDate` |
| Store, product, and customer IDs | Lookups in their dimensions to obtain warehouse keys |
| Quantity and transaction-time unit price | Line measurements; also used to calculate the line amount |
| Unidentified customer, represented by source ID `0` | A descriptive “Unknown customer” dimension row |

The loader supplies a small example of these lookups. Building a complete ETL
pipeline is not part of this session.

## 3. Environment, schema, and data

### Environment preparation

We use the same PostgreSQL and pgAdmin tools as in Practice 2. Create an empty
folder on your computer for this practice, for example `star-schema-practice`,
outside the course repository. This is your **workspace**: you will add files to
it as you work through the exercise. You can read the course materials on GitHub
or in a local checkout; cloning the repository is not required.

1. Save the supplied [compose.yml](compose.yml) and [.gitignore](.gitignore) in
   your workspace, keeping those filenames. Copy their contents or download the
   raw files from the links.
2. Example environment variables are in [.env_example](.env_example). Copy its
   contents into `.env` in the same folder as `compose.yml`, keeping the variable
   names and structure. Set the values for your local database and pgAdmin.
3. Create an empty `sql` folder. You will save the SQL files there in later steps.

Your initial workspace should look like this:

```text
star-schema-practice/
├── compose.yml
├── .env
├── .gitignore
└── sql/
```

The supplied configuration uses host ports **5434** for PostgreSQL and **5052**
for pgAdmin, so it can run alongside the earlier practice. Starting the services
also creates `pgdata/` in your workspace for PostgreSQL's database files.

> **Why keep an example file and a local settings file?**
>
> We track `.env_example` in Git to document the required variables using safe
> demonstration values. Your `.env` holds your local settings, which may include
> passwords. The supplied `.gitignore` excludes `.env` and `pgdata/` if you put
> your workspace under Git version control. Keep real credentials out of tracked
> files. When adding a required variable, update the example as well. Ignoring
> `.env` does not encrypt it or remove secrets already committed to Git history.

Open a terminal in your workspace, **in the folder containing `compose.yml`**.
Run all `docker compose` commands in this guide from that folder:

```bash
docker compose up -d
docker compose ps
```

The `-d` option runs the services in the background, leaving your terminal free.
`docker compose ps` shows their status. Wait until `db` reports `healthy` before
running SQL; if it is still starting, check the status again after a few seconds.

The Compose mount `./sql:/sql:ro` makes your local `sql/` folder available at
`/sql/` inside the database container. `ro` means the container can read these
files; you edit them on your computer. Files added to this folder later are also
available in the container without restarting it.

Choose one SQL client:

| Client | Connection |
| --- | --- |
| Terminal inside the database container | `docker compose exec db psql` |
| pgAdmin | Open `http://localhost:5052`, log in with the pgAdmin values in `.env`, and register a server with host `db`, port `5432`, and the PostgreSQL database/user/password from `.env` |
| A client installed on your computer, such as DBeaver | Host `localhost`, port `5434`, and the PostgreSQL values from `.env` |

If you changed the host ports in `.env`, use those instead. The practice tables
are in the `star` schema, inside the default `star_schema` database. Include the
schema name when writing queries, for example `star.FactSales` or `star.DimProduct`.

### Complete the starter schema

Save the [starter schema](starter/01_create_tables.sql) as
`sql/01_create_tables.sql` in your workspace, then open your local copy in an
editor. The dimensions and most of the fact table are supplied. Replace the three
placeholders with:

1. The customer dimension reference, including its key column.
2. The columns that uniquely identify a source purchase line.
3. The rule relating the line amount to its quantity and unit price.

The ordinary dimensions have generated surrogate keys and separate source IDs.
The calendar dimension uses a deterministic `YYYYMMDD` key; use its attributes,
not arithmetic on that key, for calendar analysis.

### Run the SQL files

Save the supplied [data loader](starter/02_load_data.sql) as
`sql/02_load_data.sql` in your workspace. Once you have completed the starter
schema, run these commands from the folder containing `compose.yml`:

```bash
docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/01_create_tables.sql
docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/02_load_data.sql
```

`docker compose exec db psql` runs PostgreSQL's command-line client inside the
database container. The options mean:

- `-v ON_ERROR_STOP=1` tells `psql` to stop the script at the first SQL error.
  By default, it continues, which can produce further errors that hide the
  original problem. Fix the reported error before running the next file.
- `-f` selects the SQL file to execute inside the container. For example, your
  local `sql/02_load_data.sql` is available there as `/sql/02_load_data.sql`.

The first command intentionally **recreates the `star` schema and deletes its
previous practice data**. It does not reset the whole database. The loader replaces
only the data in the five practice tables, so it can be rerun to restore the
sample data. Both scripts use transactions, so a failed run does not leave their
changes partly applied.

Alternatively, paste the complete contents of each local SQL file into pgAdmin's
Query Tool and execute them in the same order. With DBeaver, open the local files
and execute each as a script. The `/sql/` paths above belong to the database
container; use your local copies with these clients. If an error leaves a
transaction open, issue `ROLLBACK;` before trying the corrected file again.

<details>
<summary>Reference schema if you need help or are short of time</summary>

Compare your choices with [the completed schema](solution/01_create_tables.sql).
To run it, save a separate copy as `sql/01_create_tables_reference.sql` in your
workspace, preserving your starter work. Use the data loader you saved above:

```bash
docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/01_create_tables_reference.sql
docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/02_load_data.sql
```

The [reference guide](solution/README.md) includes the model diagram and explanations.

</details>

### Inspect the sample data

There are **15 purchase lines, 7 purchases, 43 units, and EUR 56.90 in revenue**.
The calendar covers September and October 2026, including days without sales.

Inspect purchase IDs `1001` and `1002` (Alice's separate purchases on the same
day) and purchase `1006` (an unidentified shopper with Apple on two lines).
Locate these cases in your local `sql/02_load_data.sql`. They are intentional
tests of your grain and aggregation choices.

## 4. Analytical exercises

Create `sql/03_analysis.sql` in your workspace and save your answers there. Run
queries in your chosen SQL client. Use dimension attributes for readable labels
and source or warehouse identifiers to distinguish entities that might share a name.

### A. Store revenue: month to day

Write two queries to answer how revenue varies over time for each store:

1. **Monthly report:** one row per store and calendar month, with year, month,
   store ID, store name, and revenue in EUR. Sort by year, month, then store ID.
2. **Daily report:** drill down to one row per store and date, with date, store ID,
   store name, and revenue in EUR. Sort by date, then store ID.

**Hint:** join `star.FactSales` to `star.DimDate` and `star.DimStore` using their
keys, then sum `SalesAmount` for each group. Use both `CalendarYear` and
`MonthNumber` for the monthly report, and `FullDate` for the daily report.

Explain what changes in your query and what remains unchanged in the stored fact
rows. Days with no sales may be absent from the result; producing zero-sales days
is optional.

### B. Categories and products

Write two queries to identify what generates the most revenue:

1. **Category report:** one row per category, with category and revenue in EUR,
   highest revenue first.
2. **Top products:** three rows, with product ID, product name, and revenue in EUR,
   highest revenue first. Use ascending product ID to break revenue ties.

**Hint:** both reports use the same join to `star.DimProduct`. Change the grouping
from category to product; apply `ORDER BY` before `LIMIT 3` in the product report.

Explain why a product's category is useful as a dimension attribute and why the
category report can use the same fact table as the product report.

### C. Average basket size

Find how many units are bought in an average completed purchase. Produce:

1. **Basket totals:** one row per purchase, with `PurchaseID` and total units,
   ordered by purchase ID. The sample data should produce seven rows.
2. **Average basket size:** one value, the average of those seven totals, displayed
   to four decimal places. Each purchase must contribute equally, regardless of
   its number of lines.

**Hint:** first sum `Quantity` grouped by `PurchaseID`. Use that result in a
subquery or `WITH` expression, then apply `AVG` to the purchase totals.

Explain why grouping by customer and day would merge purchases `1001` and `1002`.
What would you change if management asked for distinct products per basket?

### D. Average selling price

Find the average price actually paid per unit of each product. Return one row per
product with product ID, product name, total units, revenue in EUR, average price
paid per unit, and `AVG(UnitPrice)` for comparison. Sort by product ID and display
both average prices to four decimal places.

**Hint:** divide the product's total revenue by its total units:
`SUM(SalesAmount) / SUM(Quantity)`. Calculate before rounding; use `ROUND(..., 4)`
for display.

Use Apple's purchases to explain why the two results differ. Which calculation
answers the business question, and what does the other calculation measure?

## 5. Validate and diagnose

First write checks of your own: count rows and purchases, total units and revenue,
and confirm that joining all four dimensions preserves the fact count and revenue.
Reconcile the daily store totals with the monthly totals. How would a missing or
nonunique dimension match affect these checks?

Save the supplied [data checks](starter/04_validate.sql) as
`sql/04_validate.sql` in your workspace, then run them from the folder containing
`compose.yml`:

```bash
docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/04_validate.sql
```

All checks should report `t` (true). The script raises an error if an expectation
fails. It checks the loaded data, not the SQL answers saved in your editor;
compare those separately with the [expected results](solution/README.md#expected-results).

This query runs successfully but is labeled incorrectly:

```sql
SELECT c.CustomerID, d.FullDate, AVG(f.Quantity) AS AverageBasketSize
FROM star.FactSales AS f
JOIN star.DimCustomer AS c ON c.CustomerKey = f.CustomerKey
JOIN star.DimDate AS d ON d.DateKey = f.DateKey
GROUP BY c.CustomerID, d.FullDate;
```

For Alice on September 30 it returns `2.5`. Her two baskets contain `3` and `7`
units, so their average is `5`. Explain both problems: the query averages lines,
and its grouping does not identify purchases. Correct it using your answer to C.

## 6. Discussion

Be ready to explain:

- Your declared fact grain, and why a report can group at a coarser level.
- Why revenue adds across stores and dates, but unit prices should not be summed.
- Why a star schema helps an analyst navigate business labels and measures.
- One process in your course project that could use a similar design, and a
  business question it would support.

A normalized operational model and a dimensional analytical model serve different
workloads. A star schema is still relational and can be drawn as an ER diagram;
its simpler business-facing structure does not guarantee faster queries in every
case. This tiny dataset demonstrates correctness, not a performance benchmark.

## Optional extensions — outside the required session

Choose these after completing the core work; none is a prerequisite for it.

- **Customer history (20–30 minutes):** [SCD Type 2 exercise](optional/scd2/README.md)
  with its own schema and fixed event dates. Investigate a move and a late-arriving sale.
- **Shared dimensions (5–10 minutes):** sketch a bus matrix with sales and daily
  inventory as rows and Date, Product, Store, and Customer as columns. Which
  dimensions can be shared? Why can inventory balance be added across stores
  but not across consecutive dates? No second fact table implementation is required.
- **Model boundaries (5–10 minutes):** consider a purchase paid partly by cash and
  partly by card. Explain why copying the full purchase revenue to both payment
  methods would double count it. Discuss what additional source data you would need.
- **Zero-sales days (10 minutes):** extend A to show all calendar days for each
  store, including zero revenue. Keep this separate from the required query.

## References

- [Solution guide and expected results](solution/README.md)
- [Reference queries](solution/03_analysis.sql)
- [The Data Warehouse Toolkit, 3rd edition, chapters 1 and 2](https://learning.oreilly.com/library/view/the-data-warehouse/9781118530801/)
- [Kimball's four-step design process](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/four-4-step-design-process/)
- [Additive, semi-additive, and non-additive facts](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/additive-semi-additive-non-additive-fact/)

## Stopping and troubleshooting

From the folder containing `compose.yml`, `docker compose down` stops and removes
this lesson's containers. The database files remain in your workspace's
`pgdata/` directory, which the supplied `.gitignore` excludes from Git. Rerun the
schema and load scripts to reset the core exercise; no database-directory deletion
is needed. PostgreSQL credentials and database creation settings in `.env` apply
when that data directory is first initialized, not on every restart.

| Symptom | Check |
| --- | --- |
| Compose cannot find a configuration file | Open the terminal in your workspace, in the folder containing `compose.yml`. |
| `psql` cannot open `/sql/...` | Save the named file under your workspace's `sql/` folder. Check its filename and ensure you downloaded SQL rather than a GitHub HTML page. |
| A port is already allocated | Choose a free `POSTGRES_PORT` or `PGADMIN_PORT` in `.env`, recreate the containers, and update your client connection. |
| Relation `factsales` does not exist | Run the schema and loader; select the configured database and `star` schema. |
| Syntax error containing `__...__` | Complete all three starter placeholders or use the reference schema. |
| A validation check fails | Inspect the first failed expectation and your schema changes; reload the sample data before comparing reference answers. |
| Credentials fail after editing `.env` | An existing `pgdata` keeps its original database and credentials. Use those settings or prepare a separate empty data directory, preserving any data you need. |
