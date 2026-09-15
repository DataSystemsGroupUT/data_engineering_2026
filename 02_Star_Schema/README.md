# Practice 3: Dimensional Modeling and Star Schemas

Build and query a small sales warehouse in PostgreSQL. Starting from supermarket
business questions, you will complete a star schema, load purchase lines, and
check that your analytical queries answer the questions you intended to ask.

The lecture introduces dimensional modeling. This practical focuses on applying
those concepts; customer history and broader warehouse architecture are optional
extensions.

## Learning outcomes

By the end of the required session, you should be able to:

- State the grain of a fact table and distinguish it from a query's grouping level.
- Connect facts to dimensions using warehouse keys while retaining source identifiers.
- Calculate revenue, basket size, and average selling price at the correct grain.
- Verify that joins and aggregations preserve the meaning and totals of the data.

**Prerequisites:** the Docker and PostgreSQL setup from earlier practices, basic
SQL joins and `GROUP BY`, and the lecture's introduction to facts, dimensions,
grain, and surrogate keys. A subquery or common table expression (`WITH`) will be
useful for the basket exercise.

## Session plan — at most 105 minutes

| Activity | Minutes | Deliverable |
| --- | ---: | --- |
| Business questions and scope | 5 | Shared understanding of the measures |
| Design worksheet in pairs | 15 | Grain, keys, dimensions, and facts |
| Complete the schema and load the data | 20 | Working star schema |
| Four analytical exercises | 30 | Queries with explained results |
| Validation and one misleading query | 15 | Reconciled totals and a corrected calculation |
| Discussion and connection to the course project | 10 | A justified modeling decision |
| Flexible buffer | 10 | Setup help and questions |
| **Total** | **105** | **95 minutes planned, 10 minutes flexible** |

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

## 2. Design worksheet — 15 minutes

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

## 3. Environment, schema, and data — 20 minutes

### Environment preparation

We use the same PostgreSQL and pgAdmin tools as in Practice 2. This lesson has its
own [Compose configuration](solution/compose.yml), project name, and data directory.
Its default host ports are **5434** for PostgreSQL and **5052** for pgAdmin, so it
can run alongside the earlier practice.

Example environment variables are provided in
[solution/.env_example](solution/.env_example). Copy its contents into a file
named `.env` in the same folder as `compose.yml`, keeping the variable names and
structure. Set the values for your local database and pgAdmin environment before
starting the services.

> [!NOTE]
> **Why keep an example file and a local settings file?**
>
> We track `.env_example` in Git to document the required variables using safe
> demonstration values. Your `.env` holds your local settings, which may include
> passwords, and is excluded from Git. Keep real credentials out of tracked files.
> When adding a required variable, update the example as well. Ignoring `.env`
> does not encrypt it or remove secrets already committed to Git history.

Run the following commands **from `02_Star_Schema/solution`**:

```bash
docker compose up -d --wait
docker compose ps
```

Choose one SQL client:

| Client | Connection |
| --- | --- |
| Terminal inside the database container | `docker compose exec db psql` |
| pgAdmin | Open `http://localhost:5052`, log in with the pgAdmin values in `.env`, and register a server with host `db`, port `5432`, and the PostgreSQL database/user/password from `.env` |
| A client installed on your computer | Host `localhost`, port `5434`, and the PostgreSQL values from `.env` |

If you changed the host ports in `.env`, use those instead. SQL objects are in
the `star` schema, inside the default `star_schema` database. In a new query
session, use `SET search_path TO star, public;`, or qualify names such as
`star.FactSales`. PostgreSQL treats the unquoted mixed-case identifiers in these
scripts as lowercase; do not add double quotes when querying them.

### Complete the starter schema

Open [starter/01_create_tables.sql](starter/01_create_tables.sql). The dimensions
and most of the fact table are supplied. Replace the three placeholders with:

1. The customer dimension reference, including its key column.
2. The columns that uniquely identify a source purchase line.
3. The rule relating the line amount to its quantity and unit price.

The ordinary dimensions have generated surrogate keys and separate source IDs.
The calendar dimension uses a deterministic `YYYYMMDD` key; use its attributes,
not arithmetic on that key, for calendar analysis.

Once you have completed the file, run it and the supplied loader:

```bash
docker compose exec db psql -X -v ON_ERROR_STOP=1 -f /starter/01_create_tables.sql
docker compose exec db psql -X -v ON_ERROR_STOP=1 -f /sql/02_load_data.sql
```

The first command intentionally **recreates the `star` schema and deletes its
previous practice data**. It does not reset the whole database. The loader replaces
only the data in the five practice tables, so it can be rerun to restore the
fixture. Both scripts use transactions; `ON_ERROR_STOP` stops the command when a
statement fails.

You can also execute each complete file in pgAdmin's Query Tool, in the same
order. If an error leaves a transaction open there, issue `ROLLBACK;` before
trying the corrected file again.

<details>
<summary>Reference schema if you need help or are short of time</summary>

Compare your choices with [the completed schema](solution/pgtmp/01_create_tables.sql).
You can run it instead of the starter with:

```bash
docker compose exec db psql -X -v ON_ERROR_STOP=1 -f /sql/01_create_tables.sql
docker compose exec db psql -X -v ON_ERROR_STOP=1 -f /sql/02_load_data.sql
```

The [reference guide](solution/README.md) includes the model diagram and explanations.

</details>

### Inspect the fixture

There are **15 purchase lines, 7 purchases, 43 units, and EUR 56.90 in revenue**.
The calendar covers September and October 2026, including days without sales.

Inspect purchase IDs `1001` and `1002` (Alice's separate purchases on the same
day) and purchase `1006` (an unidentified shopper with Apple on two lines).
Locate these cases in [the source rows](solution/pgtmp/02_load_data.sql). They are
intentional tests of your grain and aggregation choices.

## 4. Analytical exercises — 30 minutes

Write and save your own SQL. Use dimension attributes for readable labels and
source or warehouse identifiers to distinguish entities that might share a name.

### A. Store revenue: month to day — 7 minutes

Calculate revenue for each store and calendar month. Include the year in your
grouping. Then drill down to daily revenue for each store.

Explain what changes in your query and what remains unchanged in the stored fact
rows. Days with no sales may be absent from the result; producing zero-sales days
is optional.

### B. Categories and products — 6 minutes

Calculate revenue by category, then find the three products with the highest
revenue. Use product ID as a tie-breaker if revenue is equal.

Explain why a product's category is useful as a dimension attribute and why the
category report can use the same fact table as the product report.

### C. Average basket size — 9 minutes

Calculate the units in each purchase, then the average across all purchases.
Every purchase must contribute equally to the average, regardless of its number
of lines. Use a subquery or `WITH` expression for the intermediate result.

Explain why grouping by customer and day would merge purchases `1001` and `1002`.
What would you change if management asked for distinct products per basket?

### D. Average selling price — 8 minutes

For each product, report units, revenue, and average price paid per unit. Compare
`SUM(SalesAmount) / SUM(Quantity)` with `AVG(UnitPrice)`. Round displayed prices
to four decimal places, retaining the original precision during calculation.

Use Apple's purchases to explain why the two results differ. Which calculation
answers the business question, and what does the other calculation measure?

## 5. Validate and diagnose — 15 minutes

First write checks of your own: count rows and purchases, total units and revenue,
and confirm that joining all four dimensions preserves the fact count and revenue.
Reconcile the daily store totals with the monthly totals. How would a missing or
nonunique dimension match affect these checks?

Then run the fixture checks:

```bash
docker compose exec db psql -X -v ON_ERROR_STOP=1 -f /sql/04_validate.sql
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

## 6. Discussion — 10 minutes

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

## Reference and preparation

- [Solution guide and expected results](solution/README.md)
- [Reference queries](solution/pgtmp/03_analysis.sql)
- [Lecturer preparation notes](LECTURER_NOTES.md)
- [The Data Warehouse Toolkit, 3rd edition, chapters 1 and 2](https://learning.oreilly.com/library/view/the-data-warehouse/9781118530801/)
- [Kimball's four-step design process](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/four-4-step-design-process/)
- [Additive, semi-additive, and non-additive facts](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/additive-semi-additive-non-additive-fact/)

## Stopping and troubleshooting

From `solution`, `docker compose down` stops and removes this lesson's containers.
The database files remain in the ignored `solution/pgdata/` directory. Rerun the
schema and load scripts to reset the core exercise; no database-directory deletion
is needed. PostgreSQL credentials and database creation settings in `.env` apply
when that data directory is first initialized, not on every restart.

| Symptom | Check |
| --- | --- |
| A port is already allocated | Choose a free `POSTGRES_PORT` or `PGADMIN_PORT` in `.env`, recreate the containers, and update your client connection. |
| Relation `factsales` does not exist | Run the schema and loader; select the configured database and `star` schema. |
| Syntax error containing `__...__` | Complete all three starter placeholders or use the reference schema. |
| A validation check fails | Inspect the first failed expectation and your schema changes; restore the fixture before comparing reference answers. |
| Credentials fail after editing `.env` | An existing `pgdata` keeps its original database and credentials. Use those settings or prepare a separate empty data directory, preserving any data you need. |
