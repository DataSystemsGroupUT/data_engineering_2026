BEGIN;
SET search_path TO scd_demo, public;
CREATE TEMP TABLE SCDChecks (CheckName TEXT, Passed BOOLEAN NOT NULL) ON COMMIT DROP;
INSERT INTO SCDChecks VALUES
    ('2 versions of the same customer', (
        SELECT COUNT(*) = 2 AND COUNT(DISTINCT CustomerID) = 1 FROM DimCustomer
    )),
    ('Exactly one current version', (SELECT COUNT(*) = 1 FROM DimCustomer WHERE IsCurrent)),
    ('No overlapping validity intervals', NOT EXISTS (
        SELECT 1 FROM DimCustomer AS a JOIN DimCustomer AS b
          ON a.CustomerID = b.CustomerID AND a.CustomerKey < b.CustomerKey
         AND a.ValidFrom < b.ValidTo AND b.ValidFrom < a.ValidTo
    )),
    ('4 sales totaling 27.00 EUR', (SELECT COUNT(*) = 4 AND SUM(SalesAmount) = 27.00 FROM FactSales)),
    ('Every sale references its valid customer version', NOT EXISTS (
        SELECT 1 FROM FactSales AS f LEFT JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey
        WHERE c.CustomerKey IS NULL OR f.SaleDate < c.ValidFrom OR f.SaleDate >= c.ValidTo
    )),
    ('Original sale still belongs to Tallinn', (
        SELECT c.City = 'Tallinn' AND f.SalesAmount = 9.00
        FROM FactSales AS f JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey
        WHERE f.PurchaseID = 2001
    )),
    ('Late September sale belongs to Tallinn', (
        SELECT c.City = 'Tallinn' FROM FactSales AS f
        JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey WHERE f.PurchaseID = 2003
    )),
    ('Boundary-date sale belongs to Tartu', (
        SELECT c.City = 'Tartu' FROM FactSales AS f
        JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey WHERE f.PurchaseID = 2002
    )),
    ('Tallinn total 13.00 EUR', (
        SELECT SUM(f.SalesAmount) = 13.00 FROM FactSales AS f
        JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey WHERE c.City = 'Tallinn'
    )),
    ('Tartu total 14.00 EUR', (
        SELECT SUM(f.SalesAmount) = 14.00 FROM FactSales AS f
        JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey WHERE c.City = 'Tartu'
    ));
SELECT CheckName, Passed FROM SCDChecks ORDER BY CheckName;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM SCDChecks WHERE NOT Passed) THEN
        RAISE EXCEPTION 'SCD validation failed: inspect the false checks above.';
    END IF;
END;
$$;

SELECT f.PurchaseID, f.SaleDate, c.CustomerID, c.CustomerKey, c.City, f.SalesAmount
FROM FactSales AS f JOIN DimCustomer AS c ON c.CustomerKey = f.CustomerKey
ORDER BY f.SaleDate, f.PurchaseID;
COMMIT;
