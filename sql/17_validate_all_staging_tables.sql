
-- Project: Olist E-Commerce Analytics
-- Purpose: Reconcile all staging tables against source CSV counts.

USE OlistEcommerceAnalytics;
GO

-- Collect actual and expected row counts for all nine tables.
WITH staging_counts AS
(
    SELECT 'orders' AS Table_Name,
           COUNT_BIG(*) AS Actual_Rows,
           CAST(99441 AS BIGINT) AS Expected_Rows
    FROM stg.orders

    UNION ALL
    SELECT 'customers', COUNT_BIG(*), 99441
    FROM stg.customers

    UNION ALL
    SELECT 'order_items', COUNT_BIG(*), 112650
    FROM stg.order_items

    UNION ALL
    SELECT 'payments', COUNT_BIG(*), 103886
    FROM stg.payments

    UNION ALL
    SELECT 'products', COUNT_BIG(*), 32951
    FROM stg.products

    UNION ALL
    SELECT 'sellers', COUNT_BIG(*), 3095
    FROM stg.sellers

    UNION ALL
    SELECT 'order_reviews', COUNT_BIG(*), 99224
    FROM stg.order_reviews

    UNION ALL
    SELECT 'geolocation', COUNT_BIG(*), 1000163
    FROM stg.geolocation

    UNION ALL
    SELECT 'category_translation', COUNT_BIG(*), 71
    FROM stg.category_translation
)

-- Compare each SQL Server table to its original CSV count.
SELECT
    Table_Name,
    Actual_Rows,
    Expected_Rows,
    Actual_Rows - Expected_Rows AS Row_Difference,

    CASE
        WHEN Actual_Rows = Expected_Rows
        THEN 'PASS'
        ELSE 'FAIL'
    END AS Validation_Status

FROM staging_counts
ORDER BY Table_Name;
GO
