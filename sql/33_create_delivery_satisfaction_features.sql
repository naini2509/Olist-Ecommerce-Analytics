
-- Project: Olist E-Commerce Analytics
-- Purpose: Create an order-level analytical dataset
-- for delivery satisfaction and adjusted analysis.
-- Grain: One eligible reviewed order per row.

USE OlistEcommerceAnalytics;
GO

CREATE OR ALTER VIEW
analytics.vw_delivery_satisfaction_features
AS

-- Select the latest answered review for every order.
WITH ranked_reviews AS
(
    SELECT
        order_id,
        review_score,

        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY
                review_answer_timestamp DESC,
                review_creation_date DESC,
                review_id DESC
        ) AS rn

    FROM dw.fact_order_reviews
),

-- Aggregate order items before joining with orders.
-- This prevents multiple items from duplicating records.
item_summary AS
(
    SELECT
        order_id,

        COUNT(*) AS item_count,

        COUNT(DISTINCT seller_id) AS seller_count,

        SUM(item_price_brl) AS order_item_value_brl,

        SUM(freight_value_brl) AS order_freight_brl

    FROM dw.fact_order_items
    GROUP BY order_id
)

-- Combine review outcomes with order characteristics.
SELECT
    o.order_id,

    o.order_purchase_timestamp,

    c.customer_state,

    CAST(o.is_late AS INT) AS is_late,

    CASE
        WHEN r.review_score <= 2 THEN 1
        ELSE 0
    END AS low_rating_flag,

    r.review_score,

    i.item_count,
    i.seller_count,
    i.order_item_value_brl,
    i.order_freight_brl,

    DATEDIFF(
        DAY,
        CAST(o.order_purchase_timestamp AS DATE),
        CAST(o.order_estimated_delivery_date AS DATE)
    ) AS promised_delivery_days

FROM dw.fact_orders AS o

INNER JOIN dw.dim_customer AS c
    ON o.customer_id = c.customer_id

INNER JOIN ranked_reviews AS r
    ON o.order_id = r.order_id
   AND r.rn = 1

LEFT JOIN item_summary AS i
    ON o.order_id = i.order_id

WHERE o.delivery_kpi_eligible = 1;
GO

-- Validate the resulting analytical dataset.
SELECT
    COUNT(*) AS Total_Reviewed_Orders,

    COUNT(DISTINCT order_id) AS Unique_Orders,

    SUM(CASE
        WHEN is_late = 0 THEN 1 ELSE 0
    END) AS On_Time_Orders,

    SUM(CASE
        WHEN is_late = 1 THEN 1 ELSE 0
    END) AS Late_Orders,

    SUM(low_rating_flag) AS Low_Rating_Orders,

    SUM(CASE
        WHEN item_count IS NULL THEN 1 ELSE 0
    END) AS Missing_Item_Summaries

FROM analytics.vw_delivery_satisfaction_features;
GO
