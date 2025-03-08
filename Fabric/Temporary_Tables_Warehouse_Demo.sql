/*
This is my warehouse you need to create your own.
*/

USE [MSSQLTips_DW];
GO

/*
Drop tables if they already exists
*/
DROP TABLE IF EXISTS dbo.UserTable;
DROP TABLE IF EXISTS dbo.Numbers;
GO


/*
Create the Numbers table
*/
CREATE TABLE dbo.Numbers
(
   Number INT
);



/*
Q: Does this code does work

INSERT INTO dbo.Numbers (Number)
SELECT TOP 1000000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
FROM sys.all_columns s1
CROSS JOIN sys.all_columns s2
CROSS JOIN sys.all_columns s3
CROSS JOIN sys.all_columns s4;

A: No

*/



/*
Insert 1 million rows into it. You can't insert from sys objects into a permenment table
This came from https://www.cathrinewilhelmsen.net/using-a-numbers-table-in-sql-server-to-insert-test-data/
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
SELECT TOP (1000000) n FROM Nums ORDER BY n; /* Insert as many numbers as you need */
GO


/*
Let's take a look
*/
SELECT TOP 100 Number FROM dbo.Numbers;


-- Create Dimension Tables
CREATE TABLE dbo.UserTable
(
    UserId INT,
    UserName VARCHAR(260),
    UserCatagory VARCHAR(260),
    Price DECIMAL(18, 2)
);
GO

-- Insert 100,000 Rows
INSERT INTO dbo.Sales
(
    UserId,
    CustomerId,
    SaleDate,
    Quantity,
    TotalAmount
)
SELECT TOP 100000
    ABS(CHECKSUM(NEWID())) % 1000 + 1,
    ABS(CHECKSUM(NEWID())) % 1000 + 1,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
    ABS(CHECKSUM(NEWID())) % 5 + 1,
    (ABS(CHECKSUM(NEWID())) % 5 + 1) * (10 + ABS(CHECKSUM(NEWID())) % 90)
FROM dbo.Numbers n;
GO


/*
Let's create a temporary table
They are session scoped
*/

DROP TABLE IF EXISTS #TempTable
GO

CREATE TABLE #TempTable
(
   Id INT
);
GO


/*
Q: Can you create global temp tables?
A: No
*/



