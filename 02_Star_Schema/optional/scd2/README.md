# Optional: preserve customer history with SCD Type 2

**Allow 20–30 minutes outside the required session.** Use the same PostgreSQL
connection as the main practice. This exercise creates an independent `scd_demo`
schema and a smaller fixture; it does not depend on the core star tables or modify
them. Other dimensions are omitted so you can focus on customer-version selection.

## Question

Alice moves from Tallinn to Tartu on October 1, 2026. Which city should receive
credit for purchases made before and after that date? What if an older purchase
arrives in the warehouse after the move?

In the core exercise, customer attributes have one stored value. Overwriting the
city is a Type 1 change. Here, a Type 2 change creates another dimension row:

- `CustomerID` stays the same for the person.
- `CustomerKey` identifies one stored version and is referenced by facts.
- `ValidFrom` is inclusive and `ValidTo` is exclusive: `[ValidFrom, ValidTo)`.
- `IsCurrent` identifies the latest version; it is not sufficient for loading old events.

Dates are fixed so the results do not depend on when you run the exercise.

## Work through the change

Prepare your workspace and start the services using the
[environment instructions](../../README.md#environment-preparation) if you have
not already done so. Create a `scd2` folder inside your workspace's `sql` folder.
Copy each linked file there as you reach its step below, keeping its filename.
The existing SQL mount makes these files available without changing Compose.

Run commands from the folder containing `compose.yml`. Alternatively, paste each
complete local SQL file into pgAdmin's Query Tool, or open and execute it as a
script in DBeaver. The setup script **recreates only `scd_demo`**, removing
previous attempts at this extension.

The commands use `-v ON_ERROR_STOP=1` to stop each script at its first SQL error;
fix it before continuing. `-f` selects the file inside the container, where
your local `sql/scd2/` folder is available at `/sql/scd2/`. See the
[command explanation](../../README.md#run-the-sql-files) for details.

1. Save [01_setup.sql](01_setup.sql) as `sql/scd2/01_setup.sql` in your workspace,
   then run it. Inspect `scd_demo.DimCustomer` and `scd_demo.FactSales`. Alice has
   one version and one September 30 sale for EUR 9.00.

   ```bash
   docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/scd2/01_setup.sql
   ```

2. Save [02_customer_move.sql](02_customer_move.sql) as
   `sql/scd2/02_customer_move.sql`. Read it before running it and predict the city
   for each incoming sale: October 1, September 29, and October 3.
   Explain why the second record must not be assigned to the current version.

   ```bash
   docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/scd2/02_customer_move.sql
   ```

3. Query both customer versions and join the facts to them using `CustomerKey`.
   Group revenue by city. Explain why the original fact does not need updating.

4. Save [03_validate.sql](03_validate.sql) as `sql/scd2/03_validate.sql`, run it,
   and compare the results with your prediction.

   ```bash
   docker compose exec db psql -v ON_ERROR_STOP=1 -f /sql/scd2/03_validate.sql
   ```

Run the move script once per setup. To repeat the exercise, start again with
`sql/scd2/01_setup.sql`. The dimension change and new facts are committed together;
a failed lookup or constraint violation rolls back that batch. If using pgAdmin
and an error leaves a transaction open, run `ROLLBACK;` before restarting.

<details>
<summary>Expected results and explanation</summary>

| Purchase | Event date | City | Amount (EUR) |
| --- | --- | --- | ---: |
| 2003, late arrival | 2026-09-29 | Tallinn | 4.00 |
| 2001, original sale | 2026-09-30 | Tallinn | 9.00 |
| 2002, boundary date | 2026-10-01 | Tartu | 6.00 |
| 2004 | 2026-10-03 | Tartu | 8.00 |

There are two versions of customer `1001`, exactly one current version, and four
sales totaling EUR 27.00. Tallinn has EUR 13.00 and Tartu EUR 14.00. The original
EUR 9.00 sale still references its Tallinn version. The late-arriving September
sale increases Tallinn's total legitimately; it does not rewrite the original sale.

The loader explicitly finds a version using the source customer ID and event
date. A foreign key alone does not perform that lookup. Its scalar subquery fails
if several versions match, and the non-null foreign key rejects a missing match.

</details>

The example enforces one current row per customer and checks for overlapping
intervals during validation. It is a teaching example, not a complete concurrent
SCD loader: retroactive corrections and enforcement of all historical interval
rules need additional design.

Further reading: [Kimball's Type 2 technique](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/type-2/).
Return to the [main practice](../../README.md).
