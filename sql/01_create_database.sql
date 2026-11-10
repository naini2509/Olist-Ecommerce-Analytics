

-- Project: Olist E-Commerce Analytics
-- Purpose: Create the project database in SQL Server

USE master;
GO

-- Create the database if it does not already exist
IF DB_ID(N'OlistEcommerceAnalytics') IS NULL
BEGIN
    CREATE DATABASE OlistEcommerceAnalytics;
END;
GO

-- Verify the database was created successfully
SELECT
    name AS Database_Name,
    state_desc AS Database_Status
FROM sys.databases
WHERE name = N'OlistEcommerceAnalytics';
GO
