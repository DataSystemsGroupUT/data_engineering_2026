-- Reference solution. Recreates ONLY the star practice schema and its data.
BEGIN;
DROP SCHEMA IF EXISTS star CASCADE;
CREATE SCHEMA star;
SET search_path TO star, public;

CREATE TABLE DimDate (
    DateKey INTEGER PRIMARY KEY,              -- YYYYMMDD calendar key
    FullDate DATE NOT NULL UNIQUE,
    CalendarYear SMALLINT NOT NULL,
    MonthNumber SMALLINT NOT NULL,
    QuarterNumber SMALLINT NOT NULL,
    DayOfMonth SMALLINT NOT NULL,
    ISOWeekday SMALLINT NOT NULL              -- Monday = 1, Sunday = 7
);

CREATE TABLE DimStore (
    StoreKey INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    StoreID INTEGER NOT NULL UNIQUE,         -- source system identifier
    StoreName TEXT NOT NULL,
    City TEXT NOT NULL
);

CREATE TABLE DimProduct (
    ProductKey INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ProductID INTEGER NOT NULL UNIQUE,
    ProductName TEXT NOT NULL,
    Category TEXT NOT NULL
);

CREATE TABLE DimCustomer (
    CustomerKey INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    CustomerID INTEGER NOT NULL UNIQUE,
    CustomerName TEXT NOT NULL,
    City TEXT NOT NULL
);

-- Grain: one line item in a completed purchase, from a single source system.
-- A product can appear on more than one line of the same purchase.
CREATE TABLE FactSales (
    SaleKey INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    PurchaseID INTEGER NOT NULL,              -- receipt identifier; no DimPurchase
    LineNumber INTEGER NOT NULL CHECK (LineNumber > 0),
    DateKey INTEGER NOT NULL REFERENCES DimDate(DateKey),
    StoreKey INTEGER NOT NULL REFERENCES DimStore(StoreKey),
    ProductKey INTEGER NOT NULL REFERENCES DimProduct(ProductKey),
    CustomerKey INTEGER NOT NULL REFERENCES DimCustomer(CustomerKey),
    Quantity INTEGER NOT NULL CHECK (Quantity > 0),
    UnitPrice NUMERIC(10,2) NOT NULL CHECK (UnitPrice >= 0),
    SalesAmount NUMERIC(12,2) NOT NULL,
    CONSTRAINT purchase_line_unique UNIQUE (PurchaseID, LineNumber),
    CONSTRAINT sales_amount_matches_line CHECK (SalesAmount = Quantity * UnitPrice)
);
COMMIT;
