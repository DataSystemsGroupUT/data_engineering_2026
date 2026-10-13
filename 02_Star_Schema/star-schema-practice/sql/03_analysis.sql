-- A1 Monthly report: one row per store and calendar month, with year, month, store ID, store name, and revenue in EUR. Sort by year, month, then store ID.

select sum(f.salesamount) revenue, d.MonthNumber, d.CalendarYear, S.StoreID, S.StoreName
from star.factsales as F
JOIN star.dimdate as D ON f.DateKey = d.DateKey
JOIN star.dimstore as S ON f.storeKey = S.storeKey
GROUP BY d.MonthNumber, d.CalendarYear, S.StoreID, S.StoreName
ORDER BY d.CalendarYear, d.MonthNumber, S.StoreID;

-- A2 Daily report: drill down to one row per store and date, with date, store ID, store name, and revenue in EUR. Sort by date, then store ID.

select sum(f.salesamount) revenue, d.fullDate, S.StoreID, S.StoreName
from star.factsales as F
JOIN star.dimdate as D ON f.DateKey = d.DateKey
JOIN star.dimstore as S ON f.storeKey = S.storeKey
GROUP BY d.fullDate, S.StoreID, S.StoreName
ORDER BY d.fullDate, S.StoreID;

-- B1: Category report: one row per category, with category and revenue in EUR, highest revenue first.

select sum(f.salesamount) revenue, p.category
from star.factsales as F
JOIN star.dimproduct as P ON p.productKey = f.productKey
GROUP BY p.category
ORDER BY revenue;

-- B2 Top products: three rows, with product ID, product name, and revenue in EUR, highest revenue first. Use ascending product ID to break revenue ties.

select sum(f.salesamount) revenue, p.category, p.productID
from star.factsales as F
JOIN star.dimproduct as P ON p.productKey = f.productKey
GROUP BY p.category, p.productID
ORDER BY revenue DESC, p.productID
LIMIT 3;

-- C1 Basket totals: one row per purchase, with PurchaseID and total units, ordered by purchase ID. The sample data should produce seven rows.

select purchaseid, SUM(quantity) as basketUnits
from star.factsales
group by purchaseid
order by purchaseid ;

-- C2 Average basket size: one value, the average of those seven totals, displayed to four decimal places. Each purchase must contribute equally, regardless of its number of lines.

WITH baskets as ( 
select purchaseid, SUM(quantity) as basketUnits
from star.factsales
group by purchaseid
order by purchaseid )

Select FLOOR(AVG(basketunits))
FROM baskets;

-- D Find the average price actually paid per unit of each product. Return one row per product with product ID, product name, total units, revenue in EUR, average price paid per unit, and AVG(UnitPrice) for comparison. Sort by product ID and display both average prices to four decimal places. 

select p.productId, p.productName, SUM(f.salesamount) as revenue, SUM(f.quantity) as units, 
 ROUND (SUM(f.salesamount)/ NULLIF(SUM(f.quantity), 0),4) as unitprice, ROUND(AVG(f.UnitPrice),4) as avgUnitPrice
from star.factsales as f
JOIN star.dimproduct as P ON f.productKey = p.productKey 
GROUP BY p.productId, p.productName ;

-- Validation

WITH Monthly AS (
	select sum(f.salesamount) revenueMonthly, d.MonthNumber, d.CalendarYear, S.StoreID, S.StoreName
	from star.factsales as F
	JOIN star.dimdate as D ON f.DateKey = d.DateKey
	JOIN star.dimstore as S ON f.storeKey = S.storeKey
	GROUP BY d.MonthNumber, d.CalendarYear, S.StoreID, S.StoreName
	ORDER BY d.CalendarYear, d.MonthNumber, S.StoreID ),

Daily as (
select sum(f.salesamount) dailyRevenue, d.fullDate, d.MonthNumber, d.CalendarYear, S.StoreID, S.StoreName
from star.factsales as F
JOIN star.dimdate as D ON f.DateKey = d.DateKey
JOIN star.dimstore as S ON f.storeKey = S.storeKey
GROUP BY d.fullDate, S.StoreID, S.StoreName, d.MonthNumber, d.CalendarYear
ORDER BY d.fullDate, S.StoreID )

SELECT m.revenueMonthly, SUM(d.dailyRevenue) as montlybydaily, d.monthNumber 
FROM Monthly as M JOIN Daily as D  
ON  d.MonthNumber = m.monthNumber AND d.CalendarYear = m.CalendarYear AND m.storeID = d.StoreID
GROUP BY d.monthNumber, d.StoreID, d.StoreName, m.revenueMonthly;