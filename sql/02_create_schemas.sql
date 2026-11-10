
-- Project: Olist E-Commerce Analytics
-- Purpose: Create staging, warehouse, and analytics schemas.

USE OlistEcommerceAnalytics;
GO

-- Create the staging schema for original CSV data.
IF SCHEMA_ID('stg') IS NULL
    EXEC('CREATE SCHEMA stg');
GO

-- Create the data warehouse schema.
IF SCHEMA_ID('dw') IS NULL
    EXEC('CREATE SCHEMA dw');
GO

-- Create the analytics schema for reporting views.
IF SCHEMA_ID('analytics') IS NULL
    EXEC('CREATE SCHEMA analytics');
GO

-- Verify the three schemas exist.
SELECT
    name AS Schema_Name
FROM sys.schemas
WHERE name IN ('stg', 'dw', 'analytics')
ORDER BY name;
GO
