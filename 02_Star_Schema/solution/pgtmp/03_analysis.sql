-- Reference answers. Try the tasks before opening this file.
SET search_path TO star, public;

-- 1a. Monthly sales by store: year is part of the grouping, not just month.
SELECT d.CalendarYear, d.MonthNumber, s.StoreID, s.StoreName,
       SUM(f.SalesAmount) AS RevenueEUR
FROM FactSales AS f
JOIN DimDate AS d ON d.DateKey = f.DateKey
JOIN DimStore AS s ON s.StoreKey = f.StoreKey
GROUP BY d.CalendarYear, d.MonthNumber, s.StoreID, s.StoreName
ORDER BY d.CalendarYear, d.MonthNumber, s.StoreID;

-- 1b. Drill down to daily sales; the stored fact grain does not change.
SELECT d.FullDate, s.StoreID, s.StoreName, SUM(f.SalesAmount) AS RevenueEUR
FROM FactSales AS f
JOIN DimDate AS d ON d.DateKey = f.DateKey
JOIN DimStore AS s ON s.StoreKey = f.StoreKey
GROUP BY d.FullDate, s.StoreID, s.StoreName
ORDER BY d.FullDate, s.StoreID;

-- 2a. Category revenue.
SELECT p.Category, SUM(f.SalesAmount) AS RevenueEUR
FROM FactSales AS f
JOIN DimProduct AS p ON p.ProductKey = f.ProductKey
GROUP BY p.Category
ORDER BY RevenueEUR DESC, p.Category;

-- 2b. Top three products by revenue (ProductID provides a stable tie-break).
SELECT p.ProductID, p.ProductName, SUM(f.SalesAmount) AS RevenueEUR
FROM FactSales AS f
JOIN DimProduct AS p ON p.ProductKey = f.ProductKey
GROUP BY p.ProductID, p.ProductName
ORDER BY RevenueEUR DESC, p.ProductID
LIMIT 3;

-- 3a. First establish purchase grain: basket size means units, not distinct SKUs.
SELECT PurchaseID, SUM(Quantity) AS BasketUnits
FROM FactSales
GROUP BY PurchaseID
ORDER BY PurchaseID;

-- 3b. Every purchase contributes equally to the final average.
WITH Baskets AS (
    SELECT PurchaseID, SUM(Quantity) AS BasketUnits
    FROM FactSales
    GROUP BY PurchaseID
)
SELECT ROUND(AVG(BasketUnits), 4) AS AverageBasketUnits FROM Baskets;

-- 4. Sum the components before dividing: unit price is not additive.
SELECT p.ProductID, p.ProductName, SUM(f.Quantity) AS Units,
       SUM(f.SalesAmount) AS RevenueEUR,
       ROUND(SUM(f.SalesAmount) / NULLIF(SUM(f.Quantity), 0), 4) AS PricePerUnit,
       ROUND(AVG(f.UnitPrice), 4) AS UnweightedLinePrice
FROM FactSales AS f
JOIN DimProduct AS p ON p.ProductKey = f.ProductKey
GROUP BY p.ProductID, p.ProductName
ORDER BY p.ProductID;

-- Diagnostic exercise: this valid SQL answers a DIFFERENT question.
-- It reports average quantity per line in each customer/day group, not baskets.
SELECT c.CustomerID, d.FullDate, ROUND(AVG(f.Quantity), 4) AS ClaimedBasketSize
FROM FactSales AS f
JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey
JOIN DimDate AS d ON d.DateKey = f.DateKey
GROUP BY c.CustomerID, d.FullDate
ORDER BY c.CustomerID, d.FullDate;
