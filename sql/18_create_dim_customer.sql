
-- Project: Olist E-Commerce Analytics
-- Purpose: Create and populate the Customer Dimension.
-- Source: stg.customers
-- Target: dw.dim_customer
-- Grain: One record per customer_id

USE OlistEcommerceAnalytics;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Check for missing customer identifiers before loading.
    IF EXISTS (
        SELECT 1
        FROM stg.customers
        WHERE customer_id IS NULL
           OR LTRIM(RTRIM(customer_id)) = ''
           OR customer_unique_id IS NULL
           OR LTRIM(RTRIM(customer_unique_id)) = ''
    )
        THROW 50001, 'Missing customer identifiers found.', 1;

    -- Check for duplicate customer IDs after trimming.
    IF EXISTS (
        SELECT 1
        FROM stg.customers
        GROUP BY LTRIM(RTRIM(customer_id))
        HAVING COUNT(*) > 1
    )
        THROW 50002, 'Duplicate customer IDs found.', 1;

    -- Create the dimension table if it does not exist.
    IF OBJECT_ID('dw.dim_customer', 'U') IS NULL
    BEGIN
        CREATE TABLE dw.dim_customer
        (
            customer_id NVARCHAR(50) NOT NULL
                PRIMARY KEY,

            customer_unique_id NVARCHAR(50) NOT NULL,

            customer_zip_code_prefix NVARCHAR(10) NULL,

            customer_city NVARCHAR(150) NULL,

            customer_state NVARCHAR(2) NULL
        );
    END;

    -- Prevent duplicate loading when rerunning the script.
    IF EXISTS (SELECT 1 FROM dw.dim_customer)
        THROW 50003, 'Customer dimension already populated.', 1;

    -- Load standardized customer attributes.
    INSERT INTO dw.dim_customer
    (
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state
    )
    SELECT
        LTRIM(RTRIM(customer_id)),
        LTRIM(RTRIM(customer_unique_id)),
        NULLIF(LTRIM(RTRIM(customer_zip_code_prefix)), ''),
        NULLIF(LOWER(LTRIM(RTRIM(customer_city))), ''),
        NULLIF(UPPER(LTRIM(RTRIM(customer_state))), '')
    FROM stg.customers;

    -- Verify that no records were lost during transformation.
    IF (SELECT COUNT(*) FROM dw.dim_customer) <>
       (SELECT COUNT(*) FROM stg.customers)
        THROW 50004, 'Customer row-count mismatch.', 1;

    -- Commit only after validation succeeds.
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    -- Roll back all changes if any operation fails.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- Validate the completed Customer Dimension.
SELECT
    COUNT(*) AS Total_Customers,
    COUNT(DISTINCT customer_id) AS Unique_Customer_IDs,
    COUNT(DISTINCT customer_unique_id) AS Unique_Purchasers,
    COUNT(DISTINCT customer_state) AS States_Represented
FROM dw.dim_customer;
GO
