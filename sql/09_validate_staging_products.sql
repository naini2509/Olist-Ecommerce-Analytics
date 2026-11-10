
-- Project: Olist E-Commerce Analytics
-- Purpose: Validate Products data imported into SQL Server.

USE OlistEcommerceAnalytics;
GO

-- Verify the source row count and product identifier uniqueness.
-- Check whether missing product attributes were preserved.

SELECT
    COUNT(*) AS Total_Products,

    COUNT(DISTINCT product_id) AS Unique_Product_IDs,

    SUM(
        CASE
            WHEN product_category_name IS NULL
            THEN 1 ELSE 0
        END
    ) AS Missing_Categories,

    SUM(
        CASE
            WHEN product_weight_g IS NULL
            THEN 1 ELSE 0
        END
    ) AS Missing_Product_Weights,

    SUM(
        CASE
            WHEN product_length_cm IS NULL
              OR product_height_cm IS NULL
              OR product_width_cm IS NULL
            THEN 1 ELSE 0
        END
    ) AS Missing_Dimensions

FROM stg.products;
GO
