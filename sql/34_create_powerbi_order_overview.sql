
-- Project: Olist E-Commerce Analytics
-- Purpose: Create a reusable Power BI order-level reporting view.
-- Grain: One row per order_id.

USE OlistEcommerceAnalytics;
GO

CREATE OR ALTER VIEW analytics.vw_order_overview
AS

-- Aggregate product prices and freight by order.
WITH item_summary AS
(
    SELECT
        order_id,
        COUNT(*) AS item_count,
        COUNT(DISTINCT seller_id) AS seller_count,
        SUM(item_price_brl) AS item_gmv_brl,
        SUM(freight_value_brl) AS freight_brl
    FROM dw.fact_order_items
    GROUP BY order_id
),

-- Aggregate all payment records by order.
payment_summary AS
(
    SELECT
        order_id,
        COUNT(*) AS payment_record_count,
        SUM(payment_value_brl) AS payment_total_brl
    FROM dw.fact_payments
    GROUP BY order_id
),

-- Rank reviews so each order has one selected review.
ranked_reviews AS
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
)

-- Build a reporting dataset at order-level grain.
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    c.customer_city,

    CAST(o.order_purchase_timestamp AS DATE)
        AS purchase_date,

    o.order_status,
    o.delivery_kpi_eligible,
    o.is_late,
    o.days_from_promise,

    i.item_count,
    i.seller_count,
    i.item_gmv_brl,
    i.freight_brl,

    -- Preserve NULL for orders without item records.
    CASE
        WHEN i.order_id IS NOT NULL
        THEN i.item_gmv_brl + i.freight_brl
        ELSE NULL
    END AS item_and_freight_total_brl,

    p.payment_record_count,
    p.payment_total_brl,

    r.review_score,

    -- Distinguish no review from a non-low rating.
    CASE
        WHEN r.review_score IS NULL THEN NULL
        WHEN r.review_score <= 2 THEN 1
        ELSE 0
    END AS low_rating_flag,

    -- Classify reconciliation at order level.
    CASE
        WHEN i.order_id IS NULL
         AND p.order_id IS NULL
            THEN 'MISSING_BOTH'

        WHEN i.order_id IS NULL
            THEN 'MISSING_ITEMS'

        WHEN p.order_id IS NULL
            THEN 'MISSING_PAYMENTS'

        WHEN ABS(
            p.payment_total_brl
            - (i.item_gmv_brl + i.freight_brl)
        ) <= 0.01
            THEN 'MATCH'

        ELSE 'DIFFERENCE'
    END AS reconciliation_status

FROM dw.fact_orders AS o

LEFT JOIN dw.dim_customer AS c
    ON o.customer_id = c.customer_id

LEFT JOIN item_summary AS i
    ON o.order_id = i.order_id

LEFT JOIN payment_summary AS p
    ON o.order_id = p.order_id

LEFT JOIN ranked_reviews AS r
    ON o.order_id = r.order_id
   AND r.rn = 1;
GO

-- Validate the reporting view.
SELECT
    COUNT(*) AS Total_Orders,

    COUNT(DISTINCT order_id) AS Unique_Orders,

    COUNT(DISTINCT customer_unique_id)
        AS Unique_Purchasers,

    SUM(item_gmv_brl) AS Total_Item_GMV_BRL,

    SUM(freight_brl) AS Total_Freight_BRL,

    SUM(payment_total_brl) AS Total_Payments_BRL,

    SUM(CASE
        WHEN review_score IS NOT NULL THEN 1
        ELSE 0
    END) AS Reviewed_Orders

FROM analytics.vw_order_overview;
GO
