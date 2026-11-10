
-- Project: Olist E-Commerce Analytics
-- Purpose: Create the raw Customers staging table.
-- Source: olist_customers_dataset.csv

USE OlistEcommerceAnalytics;
GO

-- Create the table only if it does not exist.
IF OBJECT_ID('stg.customers', 'U') IS NULL
BEGIN
    CREATE TABLE stg.customers
    (
        customer_id NVARCHAR(50) NULL,
        customer_unique_id NVARCHAR(50) NULL,
        customer_zip_code_prefix NVARCHAR(10) NULL,
        customer_city NVARCHAR(150) NULL,
        customer_state NVARCHAR(10) NULL
    );
END;
GO

-- Verify the table structure.
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'customers'
ORDER BY ORDINAL_POSITION;
GO
