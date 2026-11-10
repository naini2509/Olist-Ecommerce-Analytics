
-- Project: Olist E-Commerce Analytics
-- Purpose: Create and populate the Product Dimension.
-- Source: stg.products, category translations, overrides.
-- Grain: One record per product_id.

USE OlistEcommerceAnalytics;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Check for missing product identifiers.
    IF EXISTS (
        SELECT 1
        FROM stg.products
        WHERE NULLIF(LTRIM(RTRIM(product_id)), '') IS NULL
    )
        THROW 50010, 'Missing product IDs found.', 1;

    -- Validate product ID uniqueness.
    IF EXISTS (
        SELECT 1
        FROM stg.products
        GROUP BY LTRIM(RTRIM(product_id))
        HAVING COUNT(*) > 1
    )
        THROW 50011, 'Duplicate product IDs found.', 1;

    -- Validate nonmissing numeric source attributes.
    -- Missing values remain NULL, but invalid numbers
    -- must not be silently converted to NULL.
    IF EXISTS (
        SELECT 1
        FROM stg.products AS p
        CROSS APPLY (
            VALUES
                (p.product_name_lenght),
                (p.product_description_lenght),
                (p.product_photos_qty),
                (p.product_weight_g),
                (p.product_length_cm),
                (p.product_height_cm),
                (p.product_width_cm)
        ) AS v(raw_value)
        WHERE NULLIF(LTRIM(RTRIM(v.raw_value)), '') IS NOT NULL
          AND TRY_CONVERT(DECIMAL(18,2), v.raw_value) IS NULL
    )
        THROW 50012, 'Invalid numeric product attribute.', 1;

    -- Create the cleaned Product Dimension.
    IF OBJECT_ID('dw.dim_product', 'U') IS NULL
    BEGIN
        CREATE TABLE dw.dim_product
        (
            product_id NVARCHAR(50) NOT NULL PRIMARY KEY,

            product_category_name NVARCHAR(255) NULL,
            product_category_english NVARCHAR(255) NOT NULL,
            category_mapping_status NVARCHAR(20) NOT NULL,

            product_name_length INT NULL,
            product_description_length INT NULL,
            product_photos_qty INT NULL,

            product_weight_g DECIMAL(18,2) NULL,
            product_length_cm DECIMAL(18,2) NULL,
            product_height_cm DECIMAL(18,2) NULL,
            product_width_cm DECIMAL(18,2) NULL
        );
    END;

    -- Prevent duplicate loading on reruns.
    IF EXISTS (SELECT 1 FROM dw.dim_product)
        THROW 50013, 'Product dimension already populated.', 1;

    -- Insert standardized product records.
    INSERT INTO dw.dim_product
    (
        product_id,
        product_category_name,
        product_category_english,
        category_mapping_status,
        product_name_length,
        product_description_length,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm
    )
    SELECT
        LTRIM(RTRIM(p.product_id)),

        NULLIF(LTRIM(RTRIM(p.product_category_name)), ''),

        -- Prefer the original translation, then custom
        -- overrides; retain an explicit fallback.
        CASE
            WHEN p.product_category_name IS NULL
                THEN 'Unknown'
            WHEN t.product_category_name_english IS NOT NULL
                THEN t.product_category_name_english
            WHEN o.product_category_name_english IS NOT NULL
                THEN o.product_category_name_english
            ELSE 'Unmapped'
        END,

        CASE
            WHEN p.product_category_name IS NULL
                THEN 'MISSING'
            WHEN t.product_category_name_english IS NOT NULL
                THEN 'ORIGINAL'
            WHEN o.product_category_name_english IS NOT NULL
                THEN 'OVERRIDE'
            ELSE 'UNMAPPED'
        END,

        TRY_CONVERT(INT,
            TRY_CONVERT(DECIMAL(18,2), p.product_name_lenght)),

        TRY_CONVERT(INT,
            TRY_CONVERT(DECIMAL(18,2), p.product_description_lenght)),

        TRY_CONVERT(INT,
            TRY_CONVERT(DECIMAL(18,2), p.product_photos_qty)),

        TRY_CONVERT(DECIMAL(18,2), p.product_weight_g),
        TRY_CONVERT(DECIMAL(18,2), p.product_length_cm),
        TRY_CONVERT(DECIMAL(18,2), p.product_height_cm),
        TRY_CONVERT(DECIMAL(18,2), p.product_width_cm)

    FROM stg.products AS p

    LEFT JOIN stg.category_translation AS t
        ON p.product_category_name = t.product_category_name

    LEFT JOIN dw.ref_category_translation_overrides AS o
        ON p.product_category_name = o.product_category_name;

    -- Verify that the transformation preserved row counts.
    IF (SELECT COUNT(*) FROM dw.dim_product) <>
       (SELECT COUNT(*) FROM stg.products)
        THROW 50014, 'Product row-count mismatch.', 1;

    -- Prevent unresolved category values from entering
    -- the reporting model without investigation.
    IF EXISTS (
        SELECT 1
        FROM dw.dim_product
        WHERE category_mapping_status = 'UNMAPPED'
    )
        THROW 50015, 'Unmapped product categories found.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    -- Undo uncommitted changes if validation fails.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- Validate the completed Product Dimension.
SELECT
    COUNT(*) AS Total_Products,

    COUNT(DISTINCT product_id) AS Unique_Product_IDs,

    SUM(CASE
        WHEN category_mapping_status = 'MISSING'
        THEN 1 ELSE 0
    END) AS Unknown_Categories,

    SUM(CASE
        WHEN category_mapping_status = 'OVERRIDE'
        THEN 1 ELSE 0
    END) AS Custom_Translated_Products,

    SUM(CASE
        WHEN category_mapping_status = 'UNMAPPED'
        THEN 1 ELSE 0
    END) AS Unmapped_Categories

FROM dw.dim_product;
GO
