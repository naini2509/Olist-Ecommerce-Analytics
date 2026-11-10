
-- Project: Olist E-Commerce Analytics
-- Purpose: Create the Products staging table.
-- Source: olist_products_dataset.csv

USE OlistEcommerceAnalytics;
GO

-- Create the table if it does not already exist.
IF OBJECT_ID('stg.products', 'U') IS NULL
BEGIN
    CREATE TABLE stg.products
    (
        product_id NVARCHAR(50) NULL,
        product_category_name NVARCHAR(255) NULL,
        product_name_lenght NVARCHAR(30) NULL,
        product_description_lenght NVARCHAR(30) NULL,
        product_photos_qty NVARCHAR(30) NULL,
        product_weight_g NVARCHAR(30) NULL,
        product_length_cm NVARCHAR(30) NULL,
        product_height_cm NVARCHAR(30) NULL,
        product_width_cm NVARCHAR(30) NULL
    );
END;
GO

-- Verify all nine columns were created correctly.
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'products'
ORDER BY ORDINAL_POSITION;
GO

-- Confirm the new staging table is empty.
SELECT COUNT(*) AS Total_Product_Records
FROM stg.products;
GO
