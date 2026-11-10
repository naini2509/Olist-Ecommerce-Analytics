
-- Project: Olist E-Commerce Analytics
-- Purpose: Validate the relationship between orders and customers.

USE OlistEcommerceAnalytics;
GO

-- Join orders with their corresponding customer records.
-- LEFT JOIN ensures orders are retained even if a
-- matching customer record is missing.

WITH orders_customers AS (
    SELECT
        o.order_id,
        o.customer_id,
        c.customer_id AS matched_customer_id,
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        o.order_status,
        o.order_purchase_timestamp
    FROM stg.orders AS o
    LEFT JOIN stg.customers AS c
        ON o.customer_id = c.customer_id
)

-- Validate that the join preserves the order count.
SELECT
    COUNT(*) AS Total_Joined_Rows,
    COUNT(DISTINCT order_id) AS Unique_Orders,
    COUNT(DISTINCT customer_unique_id) AS Unique_Purchasers,
    SUM(
        CASE
            WHEN matched_customer_id IS NULL
            THEN 1 ELSE 0
        END
    ) AS Unmatched_Orders
FROM orders_customers;
GO

-- Preview five joined records.
SELECT TOP (5)
    o.order_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp
FROM stg.orders AS o
LEFT JOIN stg.customers AS c
    ON o.customer_id = c.customer_id
ORDER BY o.order_purchase_timestamp DESC;
GO
