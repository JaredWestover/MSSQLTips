/*

What does my demo environment look like?
 > VM with Windows 2019 & 4 Cores
 > 16GB of memory
 > MAX DOP = 4
 > MAX Server Memory (MB) = 14000
 > Cost threshold = 20
 > SQL Server 2019 Developer Edition

*/
USE master;

IF DATABASEPROPERTYEX('SqlQueryStress', 'Version') IS NOT NULL
BEGIN
    ALTER DATABASE SqlQueryStress SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SqlQueryStress;
END;
GO

CREATE DATABASE SqlQueryStress;

ALTER DATABASE SqlQueryStress SET RECOVERY SIMPLE;
GO

USE SqlQueryStress;
GO

/* 

First, create a numbers table to help populate the remaining tables.
 > The article below is from Aaron Bertrand.
 > https://www.mssqltips.com/sqlservertip/4177/the-sql-server-numbers-table-explained-part-2/

*/
DECLARE @UpperBound INT = 3000000;

;WITH cteN (Number)
AS (SELECT ROW_NUMBER() OVER (ORDER BY s1.[object_id])
    FROM sys.all_columns AS s1
        CROSS JOIN sys.all_columns AS s2)
SELECT [Number]
INTO dbo.Numbers
FROM cteN
WHERE [Number] <= @UpperBound;
GO


/*

This table holds information about the employees. Think of it as a dimension.

*/
CREATE TABLE dbo.Employee
(
    Id INT IDENTITY(1, 1) NOT NULL,
    UserName VARCHAR(200) NOT NULL,
    PermissionLevel INT NOT NULL,
    CreatedDate DATETIME NOT NULL
        DEFAULT GETDATE(),
    ModifiedDate DATETIME NULL,
    CONSTRAINT PK_Employee_Id
        PRIMARY KEY CLUSTERED (Id)
);
GO

INSERT INTO dbo.Employee
(
    UserName,
    PermissionLevel
)
SELECT CONCAT(
                 SUBSTRING(
                              REPLICATE('abcdefghijklmnopqrstuvwxyz', 2),
                              (ABS(CHECKSUM(NEWID())) % 26) + 1,
                              (ABS(CHECKSUM(NEWID()) % (8 - 6 + 1)) + 6)
                          ),
                 '.',
                 SUBSTRING(
                              REPLICATE('abcdefghijklmnopqrstuvwxyz', 2),
                              (ABS(CHECKSUM(NEWID())) % 26) + 1,
                              (ABS(CHECKSUM(NEWID()) % (10 - 7 + 1)) + 7)
                          )
             ) AS UserName, --dnsndndnd.snsnsns
       CASE
           WHEN n.Number % 1000 = 0 THEN
               1 --sysadmin, we don't want too many
           ELSE
       (ABS(CHECKSUM(NEWID()) % (20 - 2 + 1)) + 2)
       END AS PermissionLevel
FROM dbo.Numbers n
WHERE n.Number <= 10000;
GO


/*

The application heavily uses the table below when users log in.
 > This table contains 3 million rows.
 > Lots of inserts and updates throughout the day.

*/

CREATE TABLE dbo.EmployeeLog
(
    Id INT IDENTITY(1, 1) NOT NULL,
    EmployeeId INT NOT NULL,
    LastLogin DATETIME2 NULL,
    Notes VARCHAR(1000) NULL,
    CreatedDate DATETIME2 NOT NULL
        DEFAULT GETDATE(),
    ModifiedDate DATETIME2 NULL,
    CONSTRAINT PK_EmployeeLog_Id
        PRIMARY KEY CLUSTERED (Id),
    CONSTRAINT FK_EmployeeLog_EmployeeId
        FOREIGN KEY (EmployeeId)
        REFERENCES dbo.Employee (Id)
);
GO

INSERT INTO dbo.EmployeeLog
(
    EmployeeId,
    LastLogin,
    Notes
)
SELECT CASE
           WHEN n.Number % 100000 = 0 THEN
               1 -- Unique Employee
           ELSE
    (ABS(CHECKSUM(NEWID()) % (10000 - 2 + 1)) + 2)
       END AS EmployeeId,
       DATEADD(DAY, RAND(CHECKSUM(NEWID())) * (1 + 3650), '2000-01-01') AS LastLogin,
       CASE
           WHEN n.Number % 25 = 0 THEN -- Every 25 rows add notes
               SUBSTRING(
                            REPLICATE('abcdefghijklmnopqrstuvwxyz', 2),
                            (ABS(CHECKSUM(NEWID())) % 26) + 1,
                            (ABS(CHECKSUM(NEWID()) % (1000 - 50 + 10)) + 50)
                        )
           ELSE
               NULL
       END AS Notes
FROM dbo.Numbers n;
GO




/* 

Let's imagine we found the query below using Query Store.

 > What's the query doing?
 > Turn on the actual execution plan and run the query below.


 > Let's check out the execution plan and see what's missing.
 
*/
SELECT el.LastLogin,
       el.Notes -- Do we really need to include this column?
FROM dbo.EmployeeLog el
WHERE el.EmployeeId = 50;
GO







/*

Are you sure it doesn't appear in the missing index DMVs?
 > An article by Greg Robidoux inspired the query below.
 > https://www.mssqltips.com/sqlservertip/1634/find-sql-server-missing-indexes-with-dmvs/

*/
SELECT mid.statement AS table_name,
       mih.column_name,
       mih.column_usage
FROM sys.dm_db_missing_index_details AS mid
    CROSS APPLY sys.dm_db_missing_index_columns(mid.index_handle) mih
    INNER JOIN sys.dm_db_missing_index_groups AS mig
        ON mig.index_handle = mid.index_handle
ORDER BY mig.index_group_handle,
         mig.index_handle,
         mih.column_id;
GO







/*

Here is a method to stop a trivial plan by Erik Darling.
 > https://erikdarling.com/whats-the-point-of-1-select-1/

*/

SELECT el.LastLogin,
       el.Notes
FROM dbo.EmployeeLog el
WHERE el.EmployeeId = 50
      AND 1 =
      (
          SELECT 1
      );
GO





/*

**IMPORTANT POINTS**

 > The query executes over 25,000 times daily. 
 > A record is added every time a user logs into the application.
 > We've verified it cannot be rewritten.

*/




/*
 
What's happened so far?

> SQL didn't provide a missing index hint.
  > It's okay since we can use Query Store to see how often it runs.
 
> SQL does not create a nonclustered index when creating a foreign key.
  > It's a common mistake developers make.
 
*/







/*

Is the index worth it?

 > 50ms x 25,000 = 20+ minutes per day 😲
 > This is a lot of wasted time. But, this change requires a lot of regression testing for QA.

Is the change worth the effort?
 > Will adding the index cause other processes to slow down, like inserts & updates?
 > Will the index cause other queries to regress?
 > How big will the index be?

SQL people will say, of course, it's worth the effort. Going from 50ms to 5ms is huge.

But how can we show the value?


*/


/*

*********BIG IDEA**********
***************************

We can use SqlQueryStress to express the performance impact at a larger scale.

Plus, SqlQueryStress is easier to use than something like JMeter.


Let's examine it now.

https://github.com/ErikEJ/SqlQueryStress
 > You can download the source code and make changes.
 > Created by: Adam Machanic
 > Maintained by: Erik Jensen

*/







/*

Enter Baseline Below:



*/










/*

Now, let's create a badly needed index.

*/
DROP INDEX IF EXISTS [IX_EmployeeLog_EmployeeId] ON dbo.EmployeeLog;
GO

CREATE NONCLUSTERED INDEX [IX_EmployeeLog_EmployeeId]
ON dbo.EmployeeLog (EmployeeId)
INCLUDE (
            Notes,
            LastLogin
        );
GO







/*

Let's rerun the query and check out the execution plan.

*/
SELECT LastLogin,
       Notes
FROM dbo.EmployeeLog e
WHERE e.EmployeeId = 50;

SELECT LastLogin,
       Notes
FROM dbo.EmployeeLog e WITH (INDEX (PK_EmployeeLog_Id))
WHERE e.EmployeeId = 50;


/*

You know what? Both of these queries execute in less than a second. 🤨

*/



/*

Head back to SqlQueryStress and rerun the 2,500 executions.


***************************************



***************************************


*/





/*
  Query Execution Times

    ##########         
    ########## 
    ##########         
    ##########         
    ##########         
    ##########         
    ##########         
    ##########         
    ##########         
    ##########             🏆
    ##########         * Winner *
    ##########         ##########  
      Before             After

*/










/* 

Why Parameter Substitution?

 > Pages are already in cache.
 > Row counts and plan choice.


*/



/* 

Different plans and times based on statistics and rows returned.

*/
SELECT e.UserName,
       el.LastLogin,
       el.Notes
FROM dbo.EmployeeLog el
    INNER JOIN dbo.Employee e
        ON e.Id = el.EmployeeId
WHERE e.PermissionLevel = 1; -- Fewer rows with a 1

SELECT e.UserName,
       el.LastLogin,
       el.Notes
FROM dbo.EmployeeLog el
    INNER JOIN dbo.Employee e
        ON e.Id = el.EmployeeId
WHERE e.PermissionLevel = 10;


/*

Don't engineer your query to work. Make it break before PROD! 👍

 > How do we create a parameter substitution list?
 > We need a query to pull our list of parameter values.

*/

SELECT Id
FROM dbo.Employee;





/*

You can download the source code and make modifications. 👩‍💻


*/







/*

If we have no time for the next items we will clean up. 🧹

*/

USE master;

IF DATABASEPROPERTYEX('SqlQueryStress', 'Version') IS NOT NULL
BEGIN
    ALTER DATABASE SqlQueryStress SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SqlQueryStress;
END;
GO


/*

🎁 Bonus: How can we tell if parameter substitution is working?

- Extented Events

*/


IF EXISTS
(
    SELECT *
    FROM sys.server_event_sessions
    WHERE name = 'SQLQueryStress'
)
BEGIN
    DROP EVENT SESSION [SQLQueryStress] ON SERVER;
END;
GO


CREATE EVENT SESSION [SQLQueryStress]
ON SERVER
    ADD EVENT sqlserver.rpc_completed
    (ACTION
     (
         sqlserver.client_app_name,
         sqlserver.database_id,
         sqlserver.query_hash,
         sqlserver.session_id
     )
     WHERE (
               [sqlserver].[database_name] = N'sqlquerystress'
               AND [sqlserver].[is_system] = (0)
			   AND [connection_reset_option] = N'None'
           )
    )
    ADD TARGET package0.ring_buffer
WITH
(
    MAX_MEMORY = 4096KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 3 SECONDS,
    MAX_EVENT_SIZE = 0KB,
    MEMORY_PARTITION_MODE = NONE,
    TRACK_CAUSALITY = ON,
    STARTUP_STATE = OFF
);
GO


ALTER EVENT SESSION [SQLQueryStress] ON SERVER STATE = START;
GO

ALTER EVENT SESSION [SQLQueryStress] ON SERVER STATE = STOP;
GO