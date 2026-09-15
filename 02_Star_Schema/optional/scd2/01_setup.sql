-- Independent extension: recreates ONLY scd_demo. The core star schema is untouched.
BEGIN;
DROP SCHEMA IF EXISTS scd_demo CASCADE;
CREATE SCHEMA scd_demo;
SET search_path TO scd_demo, public;

CREATE TABLE DimCustomer (
    CustomerKey INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    CustomerID INTEGER NOT NULL,             -- same person across versions
    CustomerName TEXT NOT NULL,
    City TEXT NOT NULL,
    ValidFrom DATE NOT NULL,
    ValidTo DATE NOT NULL,
    IsCurrent BOOLEAN NOT NULL,
    UNIQUE (CustomerID, ValidFrom),
    CHECK (ValidFrom < ValidTo),
    CHECK (IsCurrent = (ValidTo = DATE '9999-12-31'))
);
CREATE UNIQUE INDEX one_current_customer_version
    ON DimCustomer (CustomerID) WHERE IsCurrent;

CREATE TABLE FactSales (
    SaleKey INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    PurchaseID INTEGER NOT NULL,
    LineNumber INTEGER NOT NULL,
    CustomerKey INTEGER NOT NULL REFERENCES DimCustomer(CustomerKey),
    SaleDate DATE NOT NULL,
    SalesAmount NUMERIC(12,2) NOT NULL,
    UNIQUE (PurchaseID, LineNumber)
);

INSERT INTO DimCustomer
    (CustomerID, CustomerName, City, ValidFrom, ValidTo, IsCurrent)
VALUES (1001, 'Alice Smith', 'Tallinn', '2026-09-01', '9999-12-31', TRUE);

INSERT INTO FactSales (PurchaseID, LineNumber, CustomerKey, SaleDate, SalesAmount)
SELECT 2001, 1, CustomerKey, DATE '2026-09-30', 9.00
FROM DimCustomer
WHERE CustomerID = 1001
  AND DATE '2026-09-30' >= ValidFrom AND DATE '2026-09-30' < ValidTo;
COMMIT;
