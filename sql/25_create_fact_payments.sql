
-- Project: Olist E-Commerce Analytics
-- Purpose: Create and populate the Payments Fact Table.
-- Source: stg.payments
-- Target: dw.fact_payments
-- Grain: One row per order_id + payment_sequential.

USE OlistEcommerceAnalytics;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Validate required payment identifiers.
    IF EXISTS (
        SELECT 1
        FROM stg.payments
        WHERE NULLIF(LTRIM(RTRIM(order_id)), '') IS NULL
           OR TRY_CONVERT(INT, payment_sequential) IS NULL
           OR TRY_CONVERT(INT, payment_sequential) <= 0
    )
        THROW 50060, 'Invalid payment identifiers.', 1;

    -- Check composite payment-key uniqueness.
    IF EXISTS (
        SELECT 1
        FROM stg.payments
        GROUP BY
            LTRIM(RTRIM(order_id)),
            TRY_CONVERT(INT, payment_sequential)
        HAVING COUNT(*) > 1
    )
        THROW 50061, 'Duplicate payment keys found.', 1;

    -- Validate payment values and installment counts.
    -- Zero installments are retained as source values.
    IF EXISTS (
        SELECT 1
        FROM stg.payments
        WHERE TRY_CONVERT(DECIMAL(18,2), payment_value) IS NULL
           OR TRY_CONVERT(DECIMAL(18,2), payment_value) < 0
           OR TRY_CONVERT(INT, payment_installments) IS NULL
           OR TRY_CONVERT(INT, payment_installments) < 0
    )
        THROW 50062, 'Invalid payment amounts or installments.', 1;

    -- Ensure every payment references an existing order.
    IF EXISTS (
        SELECT 1
        FROM stg.payments AS p
        LEFT JOIN dw.fact_orders AS o
            ON LTRIM(RTRIM(p.order_id)) = o.order_id
        WHERE o.order_id IS NULL
    )
        THROW 50063, 'Payments referencing unknown orders.', 1;

    -- Create the Payments Fact Table if absent.
    IF OBJECT_ID('dw.fact_payments', 'U') IS NULL
    BEGIN
        CREATE TABLE dw.fact_payments
        (
            order_id NVARCHAR(50) NOT NULL,
            payment_sequential INT NOT NULL,

            payment_type NVARCHAR(30) NOT NULL,
            payment_installments INT NOT NULL,
            payment_value_brl DECIMAL(18,2) NOT NULL,

            CONSTRAINT PK_fact_payments
                PRIMARY KEY (order_id, payment_sequential),

            CONSTRAINT FK_payments_orders
                FOREIGN KEY (order_id)
                REFERENCES dw.fact_orders(order_id)
        );
    END;

    -- Prevent duplicate loading.
    IF EXISTS (SELECT 1 FROM dw.fact_payments)
        THROW 50064, 'Payments fact already populated.', 1;

    -- Ensure payment methods are not missing.
    IF EXISTS (
        SELECT 1
        FROM stg.payments
        WHERE NULLIF(LTRIM(RTRIM(payment_type)), '') IS NULL
    )
        THROW 50065, 'Missing payment methods found.', 1;

    -- Insert clean payment records.
    INSERT INTO dw.fact_payments
    (
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        payment_value_brl
    )
    SELECT
        LTRIM(RTRIM(order_id)),

        TRY_CONVERT(INT, payment_sequential),

        LOWER(LTRIM(RTRIM(payment_type))),

        TRY_CONVERT(INT, payment_installments),

        TRY_CONVERT(DECIMAL(18,2), payment_value)

    FROM stg.payments;

    -- Validate row-count reconciliation.
    IF (
        SELECT COUNT(*) FROM dw.fact_payments
    ) <> (
        SELECT COUNT(*) FROM stg.payments
    )
        THROW 50066, 'Payments row-count mismatch.', 1;

    -- Commit only after successful validation.
    COMMIT TRANSACTION;

END TRY
BEGIN CATCH

    -- Roll back changes when validation fails.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO

-- Validate the completed Payments Fact Table.
SELECT
    COUNT(*) AS Total_Payments,

    COUNT(DISTINCT order_id) AS Orders_With_Payments,

    COUNT(DISTINCT payment_type) AS Payment_Methods,

    SUM(payment_value_brl) AS Total_Payment_Value_BRL,

    SUM(CASE
        WHEN payment_value_brl = 0 THEN 1
        ELSE 0
    END) AS Zero_Value_Payments

FROM dw.fact_payments;
GO
