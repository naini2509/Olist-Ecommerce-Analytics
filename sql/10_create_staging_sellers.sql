
-- Project: Olist E-Commerce Analytics
-- Purpose: Create the Sellers staging table.
-- Source: olist_sellers_dataset.csv

USE OlistEcommerceAnalytics;
GO

-- Create the Sellers staging table if it does not exist.
IF OBJECT_ID('stg.sellers', 'U') IS NULL
BEGIN
    CREATE TABLE stg.sellers
    (
        seller_id NVARCHAR(50) NULL,
        seller_zip_code_prefix NVARCHAR(10) NULL,
        seller_city NVARCHAR(150) NULL,
        seller_state NVARCHAR(10) NULL
    );
END;
GO

-- Verify the four columns and their data types.
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'sellers'
ORDER BY ORDINAL_POSITION;
GO

-- Confirm that the new staging table is empty.
SELECT COUNT(*) AS Total_Seller_Records
FROM stg.sellers;
GO
