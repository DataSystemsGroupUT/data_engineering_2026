-- Fixture checks for the required exercise. All rows must report true.
-- Run after 02_load_data.sql. These expectations describe the supplied fixture,
-- not arbitrary production data. Compare your query results with the answer guide too.
BEGIN;
SET search_path TO star, public;
CREATE TEMP TABLE LessonChecks (
    CheckName TEXT PRIMARY KEY,
    Passed BOOLEAN NOT NULL
) ON COMMIT DROP;

INSERT INTO LessonChecks VALUES
    ('15 fact rows', (SELECT COUNT(*) = 15 FROM FactSales)),
    ('7 completed purchases', (SELECT COUNT(DISTINCT PurchaseID) = 7 FROM FactSales)),
    ('43 units', (SELECT SUM(Quantity) = 43 FROM FactSales)),
    ('56.90 EUR revenue', (SELECT SUM(SalesAmount) = 56.90 FROM FactSales)),
    ('61 calendar dates', (SELECT COUNT(*) = 61 FROM DimDate)),
    ('Unique source purchase lines', NOT EXISTS (
        SELECT PurchaseID, LineNumber FROM FactSales
        GROUP BY PurchaseID, LineNumber HAVING COUNT(*) <> 1
    )),
    ('One date, store, and customer per purchase', NOT EXISTS (
        SELECT PurchaseID FROM FactSales GROUP BY PurchaseID
        HAVING COUNT(DISTINCT DateKey) <> 1 OR COUNT(DISTINCT StoreKey) <> 1
            OR COUNT(DISTINCT CustomerKey) <> 1
    )),
    ('Every line matches all four dimensions', NOT EXISTS (
        SELECT 1 FROM FactSales AS f
        LEFT JOIN DimDate AS d ON d.DateKey = f.DateKey
        LEFT JOIN DimStore AS s ON s.StoreKey = f.StoreKey
        LEFT JOIN DimProduct AS p ON p.ProductKey = f.ProductKey
        LEFT JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey
        WHERE d.DateKey IS NULL OR s.StoreKey IS NULL
           OR p.ProductKey IS NULL OR c.CustomerKey IS NULL
    )),
    ('Dimension joins preserve 15 rows and 56.90 EUR', (
        SELECT COUNT(*) = 15 AND SUM(f.SalesAmount) = 56.90
        FROM FactSales AS f
        JOIN DimDate AS d ON d.DateKey = f.DateKey
        JOIN DimStore AS s ON s.StoreKey = f.StoreKey
        JOIN DimProduct AS p ON p.ProductKey = f.ProductKey
        JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey
    )),
    ('Unknown shopper retains 3 lines and 5.50 EUR', (
        SELECT COUNT(*) = 3 AND SUM(f.SalesAmount) = 5.50
        FROM FactSales AS f JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey
        WHERE c.CustomerID = 0
    )),
    ('Receipt 1006 retains two separate Apple lines', (
        SELECT COUNT(*) = 2 AND SUM(f.Quantity) = 3
        FROM FactSales AS f JOIN DimProduct AS p ON p.ProductKey = f.ProductKey
        WHERE f.PurchaseID = 1006 AND p.ProductID = 101
    ));

-- Check expected monthly values in BOTH directions: no missing or extra groups.
WITH Actual AS (
    SELECT d.CalendarYear::INTEGER, d.MonthNumber::INTEGER, s.StoreID,
           SUM(f.SalesAmount) AS RevenueEUR
    FROM FactSales AS f
    JOIN DimDate AS d ON d.DateKey = f.DateKey
    JOIN DimStore AS s ON s.StoreKey = f.StoreKey
    GROUP BY d.CalendarYear, d.MonthNumber, s.StoreID
), Expected (CalendarYear, MonthNumber, StoreID, RevenueEUR) AS (
    VALUES (2026, 9, 10, 13.00), (2026, 9, 20, 7.40),
           (2026, 10, 10, 18.50), (2026, 10, 20, 18.00)
)
INSERT INTO LessonChecks
SELECT 'Expected monthly store revenue',
       NOT EXISTS (SELECT * FROM Actual EXCEPT SELECT * FROM Expected)
       AND NOT EXISTS (SELECT * FROM Expected EXCEPT SELECT * FROM Actual);

WITH Daily AS (
    SELECT d.CalendarYear, d.MonthNumber, d.FullDate, f.StoreKey,
           SUM(f.SalesAmount) AS RevenueEUR
    FROM FactSales AS f JOIN DimDate AS d ON d.DateKey = f.DateKey
    GROUP BY d.CalendarYear, d.MonthNumber, d.FullDate, f.StoreKey
), RolledUp AS (
    SELECT CalendarYear, MonthNumber, StoreKey, SUM(RevenueEUR) AS RevenueEUR
    FROM Daily GROUP BY CalendarYear, MonthNumber, StoreKey
), Monthly AS (
    SELECT d.CalendarYear, d.MonthNumber, f.StoreKey, SUM(f.SalesAmount) AS RevenueEUR
    FROM FactSales AS f JOIN DimDate AS d ON d.DateKey = f.DateKey
    GROUP BY d.CalendarYear, d.MonthNumber, f.StoreKey
)
INSERT INTO LessonChecks
SELECT 'Daily revenue reconciles with monthly revenue',
       NOT EXISTS (SELECT * FROM RolledUp EXCEPT SELECT * FROM Monthly)
       AND NOT EXISTS (SELECT * FROM Monthly EXCEPT SELECT * FROM RolledUp);

WITH Baskets AS (
    SELECT PurchaseID, SUM(Quantity) AS Units FROM FactSales GROUP BY PurchaseID
)
INSERT INTO LessonChecks
SELECT 'Average basket = 6.1429 units', ROUND(AVG(Units), 4) = 6.1429 FROM Baskets;

INSERT INTO LessonChecks
SELECT 'Apple weighted price 1.1250 differs from line average 1.2400',
       ROUND(SUM(f.SalesAmount) / SUM(f.Quantity), 4) = 1.1250
       AND ROUND(AVG(f.UnitPrice), 4) = 1.2400
FROM FactSales AS f JOIN DimProduct AS p ON p.ProductKey = f.ProductKey
WHERE p.ProductID = 101;

SELECT CheckName, Passed FROM LessonChecks ORDER BY CheckName;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM LessonChecks WHERE NOT Passed) THEN
        RAISE EXCEPTION 'Practice validation failed: inspect the false checks above.';
    END IF;
END;
$$;
COMMIT;
