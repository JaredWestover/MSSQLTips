/*
mssqltips.com

https://github.com/JaredWestover/MSSQLTips
*/

/*
This demo assumes the following items are in place:
 - Workspace with Fabric capacity.
 - You created a warehouse.
*/

USE [MSSQLTips_DW];
GO

/*
Drop tables if they already exist.
*/
DROP TABLE IF EXISTS dbo.Products;
DROP TABLE IF EXISTS dbo.Numbers;
GO

/*
Create the Numbers table.
*/
CREATE TABLE dbo.Numbers
(
    Number INT
);
GO

/*
Q: Does this code work?

INSERT INTO dbo.Numbers (Number)
SELECT TOP 1000000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Number
FROM sys.all_columns s1
CROSS JOIN sys.all_columns s2
CROSS JOIN sys.all_columns s3
CROSS JOIN sys.all_columns s4;

A: No
*/

/*
Insert 1 million rows into the Numbers table.
You can't insert from system objects into a permanent/user table.

Source: https://www.cathrinewilhelmsen.net/using-a-numbers-table-in-sql-server-to-insert-test-data/
*/
;WITH
    L0   AS (SELECT 1 AS n UNION ALL SELECT 1),
    L1   AS (SELECT 1 AS n FROM L0 AS a CROSS JOIN L0 AS b),
    L2   AS (SELECT 1 AS n FROM L1 AS a CROSS JOIN L1 AS b),
    L3   AS (SELECT 1 AS n FROM L2 AS a CROSS JOIN L2 AS b),
    L4   AS (SELECT 1 AS n FROM L3 AS a CROSS JOIN L3 AS b),
    L5   AS (SELECT 1 AS n FROM L4 AS a CROSS JOIN L4 AS b),
    Nums AS (SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n FROM L5)
INSERT INTO dbo.Numbers (Number)
SELECT TOP (1000000) n FROM Nums ORDER BY n; /* Insert as many numbers as needed */
GO

/*
View sample data.
*/
SELECT TOP 100 Number FROM dbo.Numbers;
GO

/*
Create the Products table.
*/
CREATE TABLE dbo.Products
(
    ProductId INT,
    ProductName VARCHAR(260),
    ProductCategory VARCHAR(260),
    Price DECIMAL(18,2)
);
GO

/*
Insert 100,000 rows into the Products table.
*/
INSERT INTO dbo.Products
(
    ProductId,
    ProductName,
    ProductCategory,
    Price
)
SELECT TOP 100000
    n.Number AS ProductId,
    CONCAT('Product', CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR)) AS ProductName, 
    CASE
        WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 3 = 1 THEN 'Video Games'
        WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 3 = 2 THEN 'Sports Cards'
        ELSE 'VHS'
    END AS ProductCategory,
    (ABS(CHECKSUM(NEWID())) % 5 + 1) * (10 + ABS(CHECKSUM(NEWID())) % 90) AS Price
FROM dbo.Numbers n;
GO

/*
Create a temporary table.
- Temp tables are session-scoped.
*/

DROP TABLE IF EXISTS #TempProducts;
GO

CREATE TABLE #TempProducts
(
    ProductId INT,
    ProductCategory VARCHAR(260),
    Price DECIMAL(18,2)
);
GO

/*
Q: Can you create global temp tables?

A: No
*/

INSERT INTO #TempProducts (ProductId, ProductCategory, Price)
SELECT 
    ProductId, 
    CASE 
        WHEN ProductCategory = 'Video Games' THEN 'Gaming'
        WHEN ProductCategory = 'Sports Cards' THEN 'Collectibles'
        ELSE 'Retro Media'
    END AS ProductCategory,
    Price * 1.10 AS Price
FROM dbo.Products
WHERE Price < 50;
GO

/*
That did not work!
*/

/*
How about this?
*/
INSERT INTO #TempProducts (ProductId, ProductCategory, Price)
VALUES (1, 'Gaming', 42.42);
GO

/*
Now let's try to insert into the Products table.
*/
INSERT INTO dbo.Products (ProductId, ProductCategory, Price)
SELECT ProductId, ProductCategory, Price
FROM #TempProducts;
GO

/*
Q: Can we perform a join using the temp table?
A: No.
*/
SELECT p.ProductName, tp.ProductCategory
FROM dbo.Products p
INNER JOIN #TempProducts tp ON p.ProductId = tp.ProductId;
GO

/*
OPTION 1: Dynamic SQL
 - This method gets complicated quickly.
*/

DECLARE @tableName NVARCHAR(256);
DECLARE @sqlStatement NVARCHAR(MAX);

-- Generate a unique table name using a GUID (replacing dashes with underscores)
SELECT @tableName = REPLACE(CONCAT('TempTable_', NEWID()), '-', '_');

-- Create the table dynamically
SET @sqlStatement = CONCAT(
    'CREATE TABLE ', QUOTENAME(@tableName), ' (
        ProductId INT,
        ProductCategory VARCHAR(260),
        Price DECIMAL(18,2)
    );'
);

EXEC sp_executesql @sqlStatement;

-- Insert sample data dynamically
SET @sqlStatement = CONCAT(
    'INSERT INTO ', QUOTENAME(@tableName), ' (ProductId, ProductCategory, Price)
     VALUES (1, ''Gaming'', 42.42);'
);

EXEC sp_executesql @sqlStatement;

-- Select data dynamically
SET @sqlStatement = CONCAT(
    'SELECT * FROM ', QUOTENAME(@tableName), ';'
);

EXEC sp_executesql @sqlStatement;

-- Drop the table dynamically
SET @sqlStatement = CONCAT(
    'DROP TABLE ', QUOTENAME(@tableName), ';'
);

EXEC sp_executesql @sqlStatement;
GO

/*
OPTION 2: Use CTEs.
*/

/*
Drop tables.
*/
DROP TABLE IF EXISTS dbo.Products;
DROP TABLE IF EXISTS dbo.Numbers;
GO