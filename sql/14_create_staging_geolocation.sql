
-- Project: Olist E-Commerce Analytics
-- Purpose: Create the raw Geolocation staging table.
-- Source: olist_geolocation_dataset.csv

USE OlistEcommerceAnalytics;
GO

-- Create the Geolocation staging table if it does not exist.
IF OBJECT_ID('stg.geolocation', 'U') IS NULL
BEGIN
    CREATE TABLE stg.geolocation
    (
        geolocation_zip_code_prefix NVARCHAR(10) NULL,
        geolocation_lat NVARCHAR(50) NULL,
        geolocation_lng NVARCHAR(50) NULL,
        geolocation_city NVARCHAR(150) NULL,
        geolocation_state NVARCHAR(10) NULL
    );
END;
GO

-- Verify the column definitions.
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'geolocation'
ORDER BY ORDINAL_POSITION;
GO

-- Confirm that the new staging table is empty.
SELECT COUNT(*) AS Total_Geolocation_Records
FROM stg.geolocation;
GO
