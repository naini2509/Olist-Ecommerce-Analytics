
-- Project: Olist E-Commerce Analytics
-- Purpose: Build the order-level fact table.
-- Source: stg.orders
-- Target: dw.fact_orders
-- Grain: One record per order_id.

USE OlistEcommerceAnalytics;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Verify that all orders have valid primary and foreign keys.
    IF EXISTS (
        SELECT 1
        FROM stg.orders
        WHERE NULLIF(LTRIM(RTRIM(order_id)), '') IS NULL
           OR NULLIF(LTRIM(RTRIM(customer_id)), '') IS NULL
    )
        THROW 50040, 'Missing order or customer IDs.', 1;

    -- Prevent duplicate order IDs.
    IF EXISTS (
        SELECT 1
        FROM stg.orders
        GROUP BY LTRIM(RTRIM(order_id))
        HAVING COUNT(*) > 1
    )
        THROW 50041, 'Duplicate order IDs found.', 1;

    -- Create the fact table if it does not already exist.
    IF OBJECT_ID('dw.fact_orders', 'U') IS NULL
    BEGIN
        CREATE TABLE dw.fact_orders
        (
            order_id NVARCHAR(50) NOT NULL PRIMARY KEY,
            customer_id NVARCHAR(50) NOT NULL,

            order_status NVARCHAR(30) NULL,

            order_purchase_timestamp DATETIME2(0) NULL,
            order_approved_at DATETIME2(0) NULL,
            order_delivered_carrier_date DATETIME2(0) NULL,
            order_delivered_customer_date DATETIME2(0) NULL,
            order_estimated_delivery_date DATETIME2(0) NULL,

            -- Eligible only when the delivery outcome
            -- can be reliably determined.
            delivery_kpi_eligible BIT NOT NULL,

            -- NULL means the late-delivery outcome is unknown.
            is_late BIT NULL,

            -- Signed calendar-day difference from promised date.
            days_from_promise INT NULL,

            CONSTRAINT FK_fact_orders_customer
                FOREIGN KEY (customer_id)
                REFERENCES dw.dim_customer(customer_id)
        );
    END;

    -- Prevent accidental duplicate loading.
    IF EXISTS (SELECT 1 FROM dw.fact_orders)
        THROW 50042, 'Orders fact table already populated.', 1;

    -- Convert raw timestamps to SQL datetime values.
    ;WITH typed_orders AS
    (
        SELECT
            LTRIM(RTRIM(order_id)) AS order_id,
            LTRIM(RTRIM(customer_id)) AS customer_id,
            LOWER(LTRIM(RTRIM(order_status))) AS order_status,

            TRY_CONVERT(
                DATETIME2(0), NULLIF(order_purchase_timestamp, ''), 120
            ) AS purchase_date,

            TRY_CONVERT(
                DATETIME2(0), NULLIF(order_approved_at, ''), 120
            ) AS approved_date,

            TRY_CONVERT(
                DATETIME2(0), NULLIF(order_delivered_carrier_date, ''), 120
            ) AS carrier_date,

            TRY_CONVERT(
                DATETIME2(0), NULLIF(order_delivered_customer_date, ''), 120
            ) AS delivered_date,

            TRY_CONVERT(
                DATETIME2(0), NULLIF(order_estimated_delivery_date, ''), 120
            ) AS estimated_date

        FROM stg.orders
    ),

    validated_orders AS
    (
        -- Establish delivery KPI eligibility using the
        -- order status and observed timestamps.
        SELECT
            *,

            CASE
                WHEN order_status = 'delivered'
                 AND purchase_date IS NOT NULL
                 AND delivered_date IS NOT NULL
                 AND estimated_date IS NOT NULL
                 AND delivered_date >= purchase_date
                THEN 1
                ELSE 0
            END AS eligible_flag

        FROM typed_orders
    )

    -- Populate the order fact at order_id grain.
    INSERT INTO dw.fact_orders
    (
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        delivery_kpi_eligible,
        is_late,
        days_from_promise
    )
    SELECT
        order_id,
        customer_id,
        order_status,
        purchase_date,
        approved_date,
        carrier_date,
        delivered_date,
        estimated_date,

        eligible_flag,

        -- Compare calendar dates because the promised
        -- delivery field represents a date commitment.
        CASE
            WHEN eligible_flag = 0 THEN NULL
            WHEN CAST(delivered_date AS DATE) >
                 CAST(estimated_date AS DATE)
            THEN 1
            ELSE 0
        END,

        CASE
            WHEN eligible_flag = 0 THEN NULL
            ELSE DATEDIFF(
                DAY,
                CAST(estimated_date AS DATE),
                CAST(delivered_date AS DATE)
            )
        END

    FROM validated_orders;

    -- Verify that the transformation preserved order count.
    IF (SELECT COUNT(*) FROM dw.fact_orders) <>
       (SELECT COUNT(*) FROM stg.orders)
        THROW 50043, 'Order fact row-count mismatch.', 1;

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH

    -- Roll back any incomplete changes.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO

-- Validate the completed order fact table.
SELECT
    COUNT(*) AS Total_Orders,

    COUNT(DISTINCT order_id) AS Unique_Orders,

    SUM(CASE
        WHEN order_status = 'delivered'
        THEN 1 ELSE 0
    END) AS Delivered_Orders,

    SUM(CASE
        WHEN delivery_kpi_eligible = 1
        THEN 1 ELSE 0
    END) AS Eligible_Delivered_Orders,

    SUM(CASE
        WHEN is_late = 1
        THEN 1 ELSE 0
    END) AS Late_Orders

FROM dw.fact_orders;
GO
