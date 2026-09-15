-- Run once after 01_setup.sql. Rerun setup to restart the extension.
-- Validity is [ValidFrom, ValidTo): the start is included; the end is excluded.
BEGIN;
SET search_path TO scd_demo, public;

UPDATE DimCustomer
SET ValidTo = DATE '2026-10-01', IsCurrent = FALSE
WHERE CustomerID = 1001 AND IsCurrent;

INSERT INTO DimCustomer
    (CustomerID, CustomerName, City, ValidFrom, ValidTo, IsCurrent)
VALUES (1001, 'Alice Smith', 'Tartu', '2026-10-01', '9999-12-31', TRUE);

-- Three records arrive after the move, including a late September sale.
-- Resolve by BUSINESS identity and EVENT date, not by the current flag.
WITH IncomingSales (PurchaseID, LineNumber, CustomerID, SaleDate, SalesAmount) AS (
    VALUES (2002, 1, 1001, DATE '2026-10-01', 6.00),
           (2003, 1, 1001, DATE '2026-09-29', 4.00),
           (2004, 1, 1001, DATE '2026-10-03', 8.00)
)
INSERT INTO FactSales (PurchaseID, LineNumber, CustomerKey, SaleDate, SalesAmount)
SELECT s.PurchaseID, s.LineNumber,
       (SELECT c.CustomerKey FROM DimCustomer AS c
        WHERE c.CustomerID = s.CustomerID
          AND s.SaleDate >= c.ValidFrom AND s.SaleDate < c.ValidTo),
       s.SaleDate, s.SalesAmount
FROM IncomingSales AS s;

-- A scalar lookup fails if multiple versions match; NOT NULL rejects no match.
-- Any failure rolls back both the dimension change and this batch of facts.
COMMIT;
