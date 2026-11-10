
-- ============================================================
-- Project: Olist E-Commerce Analytics
-- Script: 36_create_category_order_items.sql
-- Purpose: Item-level reporting view for Power BI category analysis
-- Database: OlistEcommerceAnalytics
-- ============================================================

USE OlistEcommerceAnalytics;
GO

-- Each row represents one order item.
-- The order-level view supplies customer state, purchase date,
-- and order status without multiplying item records.

CREATE OR ALTER VIEW analytics.vw_category_order_items
AS
SELECT
    -- Order and item identifiers.
    oi.order_id,
    oi.order_item_id,
    oi.product_id,

    -- Order details for interactive Power BI filtering.
    o.purchase_date,
    o.customer_state,
    o.order_status,

    -- Standardized English product category.
    -- Unmapped or missing categories receive a fallback label.
    COALESCE(
        NULLIF(LTRIM(RTRIM(p.product_category_english)), ''),
        'Unknown / Unmapped'
    ) AS product_category,

    -- Item-level merchandise and freight values.
    oi.item_price_brl,
    oi.freight_value_brl

FROM dw.fact_order_items AS oi

-- Join each item to its parent order.
INNER JOIN analytics.vw_order_overview AS o
    ON oi.order_id = o.order_id

-- Preserve items whose product category is unavailable.
LEFT JOIN dw.dim_product AS p
    ON oi.product_id = p.product_id;
GO

-- ============================================================
-- VALIDATION 1: Verify row count and financial totals.
-- ============================================================

SELECT
    COUNT(*) AS total_order_items,
    SUM(item_price_brl) AS total_item_gmv_brl,
    SUM(freight_value_brl) AS total_freight_brl
FROM analytics.vw_category_order_items;
GO

-- ============================================================
-- VALIDATION 2: Top 10 product categories by item GMV.
-- ============================================================

SELECT TOP 10
    product_category,
    COUNT(*) AS item_count,
    COUNT(DISTINCT order_id) AS order_count,
    SUM(item_price_brl) AS total_item_gmv_brl
FROM analytics.vw_category_order_items
GROUP BY product_category
ORDER BY total_item_gmv_brl DESC;
GO

-- ============================================================
-- VALIDATION 3: Check for duplicate order-item records.
-- ============================================================

SELECT
    order_id,
    order_item_id,
    COUNT(*) AS duplicate_count
FROM analytics.vw_category_order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;
GO
