
-- Project: Olist E-Commerce Analytics
-- Purpose: Validate the Sellers staging data.

USE OlistEcommerceAnalytics;
GO

-- Verify total sellers, unique IDs, and missing values.
SELECT
    COUNT(*) AS Total_Sellers,

    COUNT(DISTINCT seller_id) AS Unique_Seller_IDs,

    SUM(
        CASE
            WHEN seller_id IS NULL THEN 1
            ELSE 0
        END
    ) AS Missing_Seller_IDs,

    SUM(
        CASE
            WHEN seller_state IS NULL THEN 1
            ELSE 0
        END
    ) AS Missing_Seller_States,

    SUM(
        CASE
            WHEN seller_zip_code_prefix IS NULL THEN 1
            ELSE 0
        END
    ) AS Missing_ZIP_Prefixes

FROM stg.sellers;
GO
