
-- Project: Olist E-Commerce Analytics
-- Purpose: Create the raw Order Items staging table.
-- Source: olist_order_items_dataset.csv

USE OlistEcommerceAnalytics;
GO

-- Create the table only if it does not exist.
IF OBJECT_ID('stg.order_items', 'U') IS NULL
BEGIN
    CREATE TABLE stg.order_items
    (
        order_id NVARCHAR(50) NULL,
        order_item_id NVARCHAR(20) NULL,
        product_id NVARCHAR(50) NULL,
        seller_id NVARCHAR(50) NULL,
        shipping_limit_date NVARCHAR(30) NULL,
        price NVARCHAR(30) NULL,
        freight_value NVARCHAR(30) NULL
    );
END;
GO

-- Verify all seven staging columns.
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'order_items'
ORDER BY ORDINAL_POSITION;
GO
