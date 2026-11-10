
-- ============================================================
-- Project: Olist E-Commerce Analytics
-- Script: 35_create_payment_method_summary.sql
-- Purpose: Create a payment-method summary view for Power BI
-- Database: OlistEcommerceAnalytics
-- ============================================================

USE OlistEcommerceAnalytics;
GO

-- Create or update the analytical view.
-- Each row represents one payment method.

CREATE OR ALTER VIEW analytics.vw_payment_method_summary
AS
SELECT
    -- Payment method, such as credit_card, boleto, or voucher.
    payment_type AS payment_method,

    -- Total number of payment records for this method.
    COUNT_BIG(*) AS payment_records,

    -- Number of distinct orders using this payment method.
    COUNT(DISTINCT order_id) AS orders_using_method,

    -- Total recorded payment value in Brazilian Real.
    CAST(
        SUM(payment_value_brl)
        AS DECIMAL(19, 2)
    ) AS total_payment_value_brl

FROM dw.fact_payments

-- Aggregate payments separately for each method.
GROUP BY payment_type;
GO

-- ============================================================
-- VALIDATION: Review payment totals by method.
-- ============================================================

SELECT
    payment_method,
    payment_records,
    orders_using_method,
    total_payment_value_brl
FROM analytics.vw_payment_method_summary
ORDER BY total_payment_value_brl DESC;
GO

-- ============================================================
-- VALIDATION: Reconcile against the payment fact table.
-- ============================================================

SELECT
    SUM(payment_records) AS total_payment_records,
    SUM(total_payment_value_brl) AS total_payment_value_brl
FROM analytics.vw_payment_method_summary;
GO
