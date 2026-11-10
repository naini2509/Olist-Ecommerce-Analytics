
-- Project: Olist E-Commerce Analytics
-- Purpose: Investigate payment discrepancies in delivered orders.
-- Grain: One row per order.

USE OlistEcommerceAnalytics;
GO

-- Remove any temporary results from an earlier execution.
DROP TABLE IF EXISTS #payment_exceptions;

-- Aggregate item and freight values at order level.
WITH item_totals AS (
    SELECT
        order_id,
        SUM(item_price_brl) AS item_total_brl,
        SUM(freight_value_brl) AS freight_total_brl
    FROM dw.fact_order_items
    GROUP BY order_id
),

-- Aggregate all payment sequences for each order.
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value_brl) AS payment_total_brl
    FROM dw.fact_payments
    GROUP BY order_id
)

-- Keep delivered orders where both monetary records
-- exist but do not reconcile within R$ 0.01.
SELECT
    o.order_id,
    i.item_total_brl,
    i.freight_total_brl,
    p.payment_total_brl,

    i.item_total_brl + i.freight_total_brl
        AS expected_total_brl,

    p.payment_total_brl
      - (i.item_total_brl + i.freight_total_brl)
        AS difference_brl

INTO #payment_exceptions

FROM dw.fact_orders AS o

INNER JOIN item_totals AS i
    ON o.order_id = i.order_id

INNER JOIN payment_totals AS p
    ON o.order_id = p.order_id

WHERE o.order_status = 'delivered'
  AND ABS(
      p.payment_total_brl
      - (i.item_total_brl + i.freight_total_brl)
  ) > 0.01;

-- Summarize the size and direction of discrepancies.
SELECT
    COUNT(*) AS Orders_With_Differences,

    SUM(CASE
        WHEN difference_brl > 0 THEN 1 ELSE 0
    END) AS Payment_Higher_Orders,

    SUM(CASE
        WHEN difference_brl < 0 THEN 1 ELSE 0
    END) AS Payment_Lower_Orders,

    SUM(difference_brl) AS Net_Difference_BRL,

    SUM(ABS(difference_brl)) AS Absolute_Difference_BRL,

    MAX(ABS(difference_brl)) AS Largest_Absolute_Difference_BRL

FROM #payment_exceptions;

-- Inspect the ten largest discrepancies.
SELECT TOP (10)
    order_id,
    item_total_brl,
    freight_total_brl,
    expected_total_brl,
    payment_total_brl,
    difference_brl

FROM #payment_exceptions

ORDER BY ABS(difference_brl) DESC, order_id;
GO
