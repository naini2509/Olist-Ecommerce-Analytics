
-- Project: Olist E-Commerce Analytics
-- Purpose: Create the raw Payments staging table.
-- Source: olist_order_payments_dataset.csv

USE OlistEcommerceAnalytics;
GO

-- Create the Payments staging table only if it does not exist.
IF OBJECT_ID('stg.payments', 'U') IS NULL
BEGIN
    CREATE TABLE stg.payments
    (
        order_id NVARCHAR(50) NULL,
        payment_sequential NVARCHAR(20) NULL,
        payment_type NVARCHAR(30) NULL,
        payment_installments NVARCHAR(20) NULL,
        payment_value NVARCHAR(30) NULL
    );
END;
GO

-- Verify the five staging columns.
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'payments'
ORDER BY ORDINAL_POSITION;
GO

-- Verify the table is initially empty.
SELECT COUNT(*) AS Total_Payment_Records
FROM stg.payments;
GO
