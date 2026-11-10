
-- Project: Olist E-Commerce Analytics
-- Purpose: Create and populate the Seller Dimension.
-- Source: stg.sellers
-- Target: dw.dim_seller
-- Grain: One record per seller_id.

USE OlistEcommerceAnalytics;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Validate that every seller has a nonblank ID.
    IF EXISTS (
        SELECT 1
        FROM stg.sellers
        WHERE NULLIF(LTRIM(RTRIM(seller_id)), '') IS NULL
    )
        THROW 50020, 'Missing seller IDs found.', 1;

    -- Check duplicate seller IDs after trimming.
    IF EXISTS (
        SELECT 1
        FROM stg.sellers
        GROUP BY LTRIM(RTRIM(seller_id))
        HAVING COUNT(*) > 1
    )
        THROW 50021, 'Duplicate seller IDs found.', 1;

    -- Validate nonblank two-character state codes.
    IF EXISTS (
        SELECT 1
        FROM stg.sellers
        WHERE NULLIF(LTRIM(RTRIM(seller_state)), '') IS NULL
           OR LEN(LTRIM(RTRIM(seller_state))) <> 2
    )
        THROW 50022, 'Invalid seller state codes.', 1;

    -- Create the dimension if it does not exist.
    IF OBJECT_ID('dw.dim_seller', 'U') IS NULL
    BEGIN
        CREATE TABLE dw.dim_seller
        (
            seller_id NVARCHAR(50) NOT NULL
                PRIMARY KEY,

            seller_zip_code_prefix NVARCHAR(10) NULL,

            seller_city NVARCHAR(150) NULL,

            seller_state NVARCHAR(2) NOT NULL
        );
    END;

    -- Stop reruns from inserting duplicate records.
    IF EXISTS (SELECT 1 FROM dw.dim_seller)
        THROW 50023, 'Seller dimension already populated.', 1;

    -- Load standardized seller attributes.
    INSERT INTO dw.dim_seller
    (
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state
    )
    SELECT
        LTRIM(RTRIM(seller_id)),

        NULLIF(
            LTRIM(RTRIM(seller_zip_code_prefix)), ''
        ),

        NULLIF(
            LOWER(LTRIM(RTRIM(seller_city))), ''
        ),

        UPPER(LTRIM(RTRIM(seller_state)))

    FROM stg.sellers;

    -- Verify no records were lost.
    IF (SELECT COUNT(*) FROM dw.dim_seller) <>
       (SELECT COUNT(*) FROM stg.sellers)
        THROW 50024, 'Seller row-count mismatch.', 1;

    -- Commit after all checks pass.
    COMMIT TRANSACTION;

END TRY
BEGIN CATCH

    -- Undo changes if a validation fails.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO

-- Validate the completed Seller Dimension.
SELECT
    COUNT(*) AS Total_Sellers,

    COUNT(DISTINCT seller_id)
        AS Unique_Seller_IDs,

    COUNT(DISTINCT seller_state)
        AS States_Represented,

    SUM(
        CASE
            WHEN seller_city IS NULL
            THEN 1 ELSE 0
        END
    ) AS Missing_Seller_Cities,

    SUM(
        CASE
            WHEN seller_zip_code_prefix IS NULL
            THEN 1 ELSE 0
        END
    ) AS Missing_ZIP_Prefixes

FROM dw.dim_seller;
GO
