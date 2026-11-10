
-- Project: Olist E-Commerce Analytics
-- Purpose: Reconcile order-item and freight totals
-- against recorded payments.
-- Grain: One record per order.

USE OlistEcommerceAnalytics;
GO

-- Aggregate Order Items to one row per order.
WITH item_totals AS
(
    SELECT
        order_id,
        SUM(item_price_brl) AS item_total_brl,
        SUM(freight_value_brl) AS freight_total_brl
    FROM dw.fact_order_items
    GROUP BY order_id
),

-- Aggregate payment records to one row per order.
payment_totals AS
(
    SELECT
        order_id,
        SUM(payment_value_brl) AS payment_total_brl
    FROM dw.fact_payments
    GROUP BY order_id
),

-- Combine both summaries without multiplying records.
order_reconciliation AS
(
    SELECT
        o.order_id,
        o.order_status,

        i.item_total_brl,
        i.freight_total_brl,
        p.payment_total_brl,

        -- Calculate the expected amount from source items.
        (i.item_total_brl + i.freight_total_brl)
            AS expected_total_brl,

        -- Calculate the difference only when both
        -- item and payment records are available.
        p.payment_total_brl
            - (i.item_total_brl + i.freight_total_brl)
            AS difference_brl,

        -- Classify the reconciliation result.
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

-- Summarize the reconciliation findings.
SELECT
    reconciliation_status,

    COUNT(*) AS Total_Orders,

    SUM(expected_total_brl)
        AS Expected_Total_BRL,

    SUM(payment_total_brl)
        AS Recorded_Payments_BRL,

    SUM(difference_brl)
        AS Total_Difference_BRL

FROM order_reconciliation

GROUP BY reconciliation_status
ORDER BY Total_Orders DESC;
GO
