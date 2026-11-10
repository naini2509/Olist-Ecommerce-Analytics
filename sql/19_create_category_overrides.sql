
-- Project: Olist E-Commerce Analytics
-- Purpose: Maintain supplementary product category translations.
-- Source: data/reference/product_category_translation_overrides.csv

USE OlistEcommerceAnalytics;
GO

-- Create a separate reference table for custom translations.
IF OBJECT_ID('dw.ref_category_translation_overrides', 'U') IS NULL
BEGIN
    CREATE TABLE dw.ref_category_translation_overrides
    (
        product_category_name NVARCHAR(255) NOT NULL PRIMARY KEY,
        product_category_name_english NVARCHAR(255) NOT NULL
    );
END;
GO

-- Insert the two custom translations only if absent.
-- Keep these values synchronized with the reference CSV.
INSERT INTO dw.ref_category_translation_overrides
(
    product_category_name,
    product_category_name_english
)
SELECT
    v.product_category_name,
    v.product_category_name_english
FROM (
    VALUES
    (
        N'portateis_cozinha_e_preparadores_de_alimentos',
        N'Portable Kitchen & Food Preparation Appliances'
    ),
    (
        N'pc_gamer',
        N'Gaming PCs'
    )
) AS v (
    product_category_name,
    product_category_name_english
)
WHERE NOT EXISTS
(
    SELECT 1
    FROM dw.ref_category_translation_overrides AS r
    WHERE r.product_category_name = v.product_category_name
);
GO

-- Verify the reference mappings.
SELECT
    product_category_name,
    product_category_name_english
FROM dw.ref_category_translation_overrides
ORDER BY product_category_name;
GO
