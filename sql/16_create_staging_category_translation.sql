
-- Project: Olist E-Commerce Analytics
-- Purpose: Create the product category translation staging table.
-- Source: product_category_name_translation.csv

USE OlistEcommerceAnalytics;
GO

-- Create the staging table if it does not already exist.
IF OBJECT_ID('stg.category_translation', 'U') IS NULL
BEGIN
    CREATE TABLE stg.category_translation
    (
        product_category_name NVARCHAR(255) NULL,
        product_category_name_english NVARCHAR(255) NULL
    );
END;
GO

-- Verify the staging table structure.
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'category_translation'
ORDER BY ORDINAL_POSITION;
GO

-- Confirm that the table is initially empty.
SELECT
    COUNT(*) AS Total_Category_Translations
FROM stg.category_translation;
GO
