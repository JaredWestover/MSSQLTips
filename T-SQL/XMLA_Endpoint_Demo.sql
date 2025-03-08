/*
mssqltips.com
*/

USE [master];
GO
 
IF DB_ID('XMLAEndpointDemo') IS NOT NULL
BEGIN
    ALTER DATABASE XMLAEndpointDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE XMLAEndpointDemo;
END;
GO
 
CREATE DATABASE XMLAEndpointDemo;
GO
 
ALTER DATABASE XMLAEndpointDemo SET RECOVERY SIMPLE;
GO
 
USE XMLAEndpointDemo;
GO


-- Drop tables if they exist
DROP TABLE IF EXISTS dbo.Sales;
DROP TABLE IF EXISTS dbo.Products;
DROP TABLE IF EXISTS dbo.Customers;
GO

-- Create Dimension Tables
CREATE TABLE dbo.Products
(
    ProductId INT IDENTITY(1, 1) PRIMARY KEY,
    ProductName VARCHAR(260),
    Category VARCHAR(260),
    Price DECIMAL(18, 2)
);
GO

CREATE TABLE dbo.Customers
(
    CustomerId INT IDENTITY(1, 1) PRIMARY KEY,
    FirstName VARCHAR(260),
    LastName VARCHAR(260),
    Region VARCHAR(260)
);
GO

-- Create Fact Table
CREATE TABLE dbo.Sales
(
    SaleId INT IDENTITY(1, 1) PRIMARY KEY,
    ProductId INT,
    CustomerId INT,
    SaleDate DATE,
    Quantity INT,
    TotalAmount DECIMAL(18, 2),
    FOREIGN KEY (ProductId) REFERENCES Products (ProductId),
    FOREIGN KEY (CustomerId) REFERENCES Customers (CustomerId)
);
GO

-- Insert 1,000 Products
INSERT INTO dbo.Products
(
    ProductName,
    Category,
    Price
)
SELECT TOP 1000
    'Product ' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR),
    CASE
        WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 3 = 1 THEN
            'Video Games'
        WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 3 = 2 THEN
            'Sports Cards'
        ELSE
            'VHS'
    END,
    CAST(RAND(CHECKSUM(NEWID())) * 100 + 10 AS DECIMAL(10, 2))
FROM sys.all_columns s1;
GO

-- Insert 1,000 Customers
INSERT INTO dbo.Customers
(
    FirstName,
    LastName,
    Region
)
SELECT TOP 1000
    'CustomerFirst' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR),
    'CustomerLast' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR),
    CASE
        WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 4 = 1 THEN
            'North'
        WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 4 = 2 THEN
            'South'
        WHEN (ROW_NUMBER() OVER (ORDER BY (SELECT NULL))) % 4 = 3 THEN
            'East'
        ELSE
            'West'
    END
FROM sys.all_columns s1;
GO

-- Insert 10,000 Sales
INSERT INTO dbo.Sales
(
    ProductId,
    CustomerId,
    SaleDate,
    Quantity,
    TotalAmount
)
SELECT TOP 10000
    ABS(CHECKSUM(NEWID())) % 1000 + 1,
    ABS(CHECKSUM(NEWID())) % 1000 + 1,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
    ABS(CHECKSUM(NEWID())) % 5 + 1,
    (ABS(CHECKSUM(NEWID())) % 5 + 1) * (10 + ABS(CHECKSUM(NEWID())) % 90)
FROM sys.all_columns s1
    CROSS JOIN sys.all_columns s2;
GO



/*
Once you are done don't forget to clean up
*/

USE [master];
GO

IF DB_ID('XMLAEndpointDemo') IS NOT NULL
BEGIN
    ALTER DATABASE XMLAEndpointDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE XMLAEndpointDemo;
END;
GO