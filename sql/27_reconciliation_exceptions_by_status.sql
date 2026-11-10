
-- Project: Olist E-Commerce Analytics
-- Purpose: Investigate payment reconciliation exceptions
-- across different order statuses.

USE OlistEcommerceAnalytics;
GO

-- Aggregate item prices and freight to order level.
WITH item_totals AS
(
    SELECT
        order_id,
        SUM(item_price_brl) AS item_total_brl,
        SUM(freight_value_brl) AS freight_total_brl
    FROM dw.fact_order_items
    GROUP BY order_id
),

-- Aggregate payment values to order level.
payment_totals AS
(
    SELECT
        order_id,
        SUM(payment_value_brl) AS payment_total_brl
    FROM dw.fact_payments
    GROUP BY order_id
),

-- Classify each order using its payment and item totals.
reconciliation AS
(
    SELECT
        o.order_id,
        o.order_status,

        p.payment_total_brl
          - (i.item_total_brl + i.freight_total_brl)
          AS difference_brl,

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
                - (i.item_total_brl + i.freight_total_brl)
            ) <= 0.01
                THEN 'MATCH'

            ELSE 'DIFFERENCE'
        END AS reconciliation_status

    FROM dw.fact_orders AS o

    LEFT JOIN item_totals AS i
        ON o.order_id = i.order_id

    LEFT JOIN payment_totals AS p
        ON o.order_id = p.order_id
)

-- Summarize reconciliation results by order status.
SELECT
    order_status,

    COUNT(*) AS Total_Orders,

    SUM(CASE
        WHEN reconciliation_status = 'MATCH'
        THEN 1 ELSE 0
    END) AS Matched_Orders,

    SUM(CASE
        WHEN reconciliation_status = 'MISSING_ITEMS'
        THEN 1 ELSE 0
    END) AS Missing_Items,

    SUM(CASE
        WHEN reconciliation_status = 'MISSING_PAYMENTS'
        THEN 1 ELSE 0
    END) AS Missing_Payments,

    SUM(CASE
        WHEN reconciliation_status = 'DIFFERENCE'
        THEN 1 ELSE 0
    END) AS Payment_Differences,

    -- Net difference for comparable but mismatched orders.
    SUM(CASE
        WHEN reconciliation_status = 'DIFFERENCE'
        THEN difference_brl
        ELSE 0
    END) AS Net_Difference_BRL

FROM reconciliation
GROUP BY order_status
ORDER BY Total_Orders DESC;
GO
