
-- Project: Olist E-Commerce Analytics
-- Purpose: Create the raw Orders staging table.
-- Source: olist_orders_dataset.csv

USE OlistEcommerceAnalytics;
GO

-- Create the table only if it does not exist.
IF OBJECT_ID('stg.orders', 'U') IS NULL
BEGIN
    CREATE TABLE stg.orders
    (
        order_id NVARCHAR(50) NULL,
        customer_id NVARCHAR(50) NULL,
        order_status NVARCHAR(30) NULL,
        order_purchase_timestamp NVARCHAR(30) NULL,
        order_approved_at NVARCHAR(30) NULL,
        order_delivered_carrier_date NVARCHAR(30) NULL,
        order_delivered_customer_date NVARCHAR(30) NULL,
        order_estimated_delivery_date NVARCHAR(30) NULL
    );
END;
GO

-- Verify that all eight columns were created.
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'orders'
ORDER BY ORDINAL_POSITION;
GO
