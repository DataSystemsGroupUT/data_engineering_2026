-- Deterministic fixture. Replaces ONLY the data in the five star tables.
-- Single source system, globally unique receipt IDs, EUR, whole units,
-- completed purchases only, no returns, discounts, or tax calculations.
BEGIN;
SET search_path TO star, public;
TRUNCATE FactSales, DimDate, DimStore, DimProduct, DimCustomer RESTART IDENTITY;

-- A complete calendar for the two reporting months, including days without sales.
INSERT INTO DimDate
    (DateKey, FullDate, CalendarYear, MonthNumber, QuarterNumber, DayOfMonth, ISOWeekday)
SELECT to_char(d, 'YYYYMMDD')::INTEGER, d::DATE,
       extract(year FROM d), extract(month FROM d), extract(quarter FROM d),
       extract(day FROM d), extract(isodow FROM d)
FROM generate_series(TIMESTAMP '2026-09-01', TIMESTAMP '2026-10-31', INTERVAL '1 day') AS dates(d);

INSERT INTO DimStore (StoreID, StoreName, City) VALUES
    (10, 'Tallinn Central', 'Tallinn'),
    (20, 'Tartu Centre', 'Tartu');

INSERT INTO DimProduct (ProductID, ProductName, Category) VALUES
    (101, 'Apple', 'Fruit'),
    (102, 'Banana', 'Fruit'),
    (103, 'Milk', 'Dairy'),
    (104, 'Bread', 'Bakery');

-- CustomerID 0 is a reserved source value for an unidentified shopper.
-- Its warehouse CustomerKey is generated like the other surrogate keys.
INSERT INTO DimCustomer (CustomerID, CustomerName, City) VALUES
    (0, 'Unknown customer', 'Unknown'),
    (1001, 'Alice Smith', 'Tallinn'),
    (1002, 'Bob Jones', 'Tartu'),
    (1003, 'Carol Kask', 'Parnu');

CREATE TEMP TABLE SourceSales (
    PurchaseID INTEGER, LineNumber INTEGER, SaleDate DATE,
    StoreID INTEGER, ProductID INTEGER, CustomerID INTEGER,
    Quantity INTEGER, UnitPrice NUMERIC(10,2)
) ON COMMIT DROP;

-- Alice makes two separate purchases on September 30.
-- Purchase 1006 contains Apple on two separate lines: product is not the line key.
INSERT INTO SourceSales VALUES
    (1001, 1, '2026-09-30', 10, 101, 1001,  2, 1.00),
    (1001, 2, '2026-09-30', 10, 103, 1001,  1, 2.00),
    (1002, 1, '2026-09-30', 10, 101, 1001,  5, 1.20),
    (1002, 2, '2026-09-30', 10, 104, 1001,  2, 1.50),
    (1003, 1, '2026-09-30', 20, 102, 1002,  3, 0.80),
    (1003, 2, '2026-09-30', 20, 103, 1002,  2, 2.50),
    (1004, 1, '2026-10-01', 10, 101, 1002, 10, 1.00),
    (1004, 2, '2026-10-01', 10, 104, 1002,  1, 2.00),
    (1005, 1, '2026-10-01', 20, 103, 1003,  4, 2.00),
    (1005, 2, '2026-10-01', 20, 104, 1003,  3, 1.50),
    (1006, 1, '2026-10-02', 20, 102,    0,  1, 1.00),
    (1006, 2, '2026-10-02', 20, 101,    0,  2, 1.50),
    (1006, 3, '2026-10-02', 20, 101,    0,  1, 1.50),
    (1007, 1, '2026-10-02', 10, 104, 1001,  4, 1.25),
    (1007, 2, '2026-10-02', 10, 102, 1001,  2, 0.75);

-- Translate source identifiers to warehouse keys. A missing lookup gives NULL,
-- so NOT NULL rejects the load rather than silently dropping a source line.
INSERT INTO FactSales
    (PurchaseID, LineNumber, DateKey, StoreKey, ProductKey, CustomerKey,
     Quantity, UnitPrice, SalesAmount)
SELECT s.PurchaseID, s.LineNumber,
       (SELECT DateKey FROM DimDate WHERE FullDate = s.SaleDate),
       (SELECT StoreKey FROM DimStore WHERE StoreID = s.StoreID),
       (SELECT ProductKey FROM DimProduct WHERE ProductID = s.ProductID),
       (SELECT CustomerKey FROM DimCustomer WHERE CustomerID = s.CustomerID),
       s.Quantity, s.UnitPrice, s.Quantity * s.UnitPrice
FROM SourceSales AS s;
COMMIT;
