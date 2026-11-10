
-- Project: Olist E-Commerce Analytics
-- Purpose: Build the Order Items Fact Table.
-- Source: stg.order_items
-- Target: dw.fact_order_items
-- Grain: One row per order_id + order_item_id.

USE OlistEcommerceAnalytics;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Validate required identifiers and item sequences.
    IF EXISTS (
        SELECT 1
        FROM stg.order_items
        WHERE NULLIF(LTRIM(RTRIM(order_id)), '') IS NULL
           OR NULLIF(LTRIM(RTRIM(product_id)), '') IS NULL
           OR NULLIF(LTRIM(RTRIM(seller_id)), '') IS NULL
           OR TRY_CONVERT(INT, order_item_id) IS NULL
           OR TRY_CONVERT(INT, order_item_id) <= 0
    )
        THROW 50050, 'Invalid order-item identifiers.', 1;

    -- Check uniqueness of the composite business key.
    IF EXISTS (
        SELECT 1
        FROM stg.order_items
        GROUP BY
            LTRIM(RTRIM(order_id)),
            TRY_CONVERT(INT, order_item_id)
        HAVING COUNT(*) > 1
    )
        THROW 50051, 'Duplicate order-item keys found.', 1;

    -- Validate prices and freight before converting to decimals.
    IF EXISTS (
        SELECT 1
        FROM stg.order_items
        WHERE TRY_CONVERT(DECIMAL(18,2), price) IS NULL
           OR TRY_CONVERT(DECIMAL(18,2), freight_value) IS NULL
           OR TRY_CONVERT(DECIMAL(18,2), price) < 0
           OR TRY_CONVERT(DECIMAL(18,2), freight_value) < 0
    )
        THROW 50052, 'Invalid price or freight value.', 1;

    -- Validate shipping deadline timestamps.
    IF EXISTS (
        SELECT 1
        FROM stg.order_items
        WHERE shipping_limit_date IS NOT NULL
          AND TRY_CONVERT(
              DATETIME2(0), shipping_limit_date, 120
          ) IS NULL
    )
        THROW 50053, 'Invalid shipping deadline.', 1;

    -- Create the fact table if absent.
    IF OBJECT_ID('dw.fact_order_items', 'U') IS NULL
    BEGIN
        CREATE TABLE dw.fact_order_items
        (
            order_id NVARCHAR(50) NOT NULL,
            order_item_id INT NOT NULL,

            product_id NVARCHAR(50) NOT NULL,
            seller_id NVARCHAR(50) NOT NULL,

            shipping_limit_date DATETIME2(0) NULL,

            item_price_brl DECIMAL(18,2) NOT NULL,
            freight_value_brl DECIMAL(18,2) NOT NULL,

            CONSTRAINT PK_fact_order_items
                PRIMARY KEY (order_id, order_item_id),

            CONSTRAINT FK_items_orders
                FOREIGN KEY (order_id)
                REFERENCES dw.fact_orders(order_id),

            CONSTRAINT FK_items_products
                FOREIGN KEY (product_id)
                REFERENCES dw.dim_product(product_id),

            CONSTRAINT FK_items_sellers
                FOREIGN KEY (seller_id)
                REFERENCES dw.dim_seller(seller_id)
        );
    END;

    -- Prevent duplicate inserts on reruns.
    IF EXISTS (SELECT 1 FROM dw.fact_order_items)
        THROW 50054, 'Order Items fact already populated.', 1;

    -- Insert clean, typed item-level transactions.
    INSERT INTO dw.fact_order_items
    (
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        item_price_brl,
        freight_value_brl
    )
    SELECT
        LTRIM(RTRIM(order_id)),
        TRY_CONVERT(INT, order_item_id),
        LTRIM(RTRIM(product_id)),
        LTRIM(RTRIM(seller_id)),

        TRY_CONVERT(
            DATETIME2(0), shipping_limit_date, 120
        ),

        TRY_CONVERT(DECIMAL(18,2), price),
        TRY_CONVERT(DECIMAL(18,2), freight_value)

    FROM stg.order_items;

    -- Verify no rows were lost or duplicated.
    IF (
        SELECT COUNT(*) FROM dw.fact_order_items
    ) <> (
        SELECT COUNT(*) FROM stg.order_items
    )
        THROW 50055, 'Order Items row-count mismatch.', 1;

    -- Commit only after successful validation.
    COMMIT TRANSACTION;

END TRY
BEGIN CATCH

    -- Undo uncommitted changes if any check fails.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO

-- Validate the completed Order Items Fact Table.
SELECT
    COUNT(*) AS Total_Order_Items,

    COUNT(DISTINCT order_id) AS Orders_With_Items,

    COUNT(DISTINCT product_id) AS Products_Sold,

    COUNT(DISTINCT seller_id) AS Active_Sellers,

    SUM(item_price_brl) AS Item_GMV_BRL,

    SUM(freight_value_brl) AS Total_Freight_BRL

FROM dw.fact_order_items;
GO
