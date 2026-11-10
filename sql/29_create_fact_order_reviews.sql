
-- Project: Olist E-Commerce Analytics
-- Purpose: Build the Customer Reviews Fact Table.
-- Source: stg.order_reviews
-- Target: dw.fact_order_reviews
-- Grain: One row per review_id + order_id.

USE OlistEcommerceAnalytics;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Validate required review and order identifiers.
    IF EXISTS (
        SELECT 1
        FROM stg.order_reviews
        WHERE NULLIF(LTRIM(RTRIM(review_id)), '') IS NULL
           OR NULLIF(LTRIM(RTRIM(order_id)), '') IS NULL
    )
        THROW 50070, 'Missing review or order IDs.', 1;

    -- Validate composite review-key uniqueness.
    IF EXISTS (
        SELECT 1
        FROM stg.order_reviews
        GROUP BY
            LTRIM(RTRIM(review_id)),
            LTRIM(RTRIM(order_id))
        HAVING COUNT(*) > 1
    )
        THROW 50071, 'Duplicate review keys found.', 1;

    -- Ensure every review score is between 1 and 5.
    IF EXISTS (
        SELECT 1
        FROM stg.order_reviews
        WHERE TRY_CONVERT(INT, review_score) IS NULL
           OR TRY_CONVERT(INT, review_score) NOT BETWEEN 1 AND 5
    )
        THROW 50072, 'Invalid review scores found.', 1;

    -- Validate nonmissing review timestamps.
    IF EXISTS (
        SELECT 1
        FROM stg.order_reviews
        WHERE (
            NULLIF(LTRIM(RTRIM(review_creation_date)), '')
                IS NOT NULL
            AND TRY_CONVERT(
                DATETIME2(0), review_creation_date, 120
            ) IS NULL
        )
        OR (
            NULLIF(LTRIM(RTRIM(review_answer_timestamp)), '')
                IS NOT NULL
            AND TRY_CONVERT(
                DATETIME2(0), review_answer_timestamp, 120
            ) IS NULL
        )
    )
        THROW 50073, 'Invalid review timestamps found.', 1;

    -- Create the Reviews Fact Table if absent.
    IF OBJECT_ID('dw.fact_order_reviews', 'U') IS NULL
    BEGIN
        CREATE TABLE dw.fact_order_reviews
        (
            review_id NVARCHAR(50) NOT NULL,
            order_id NVARCHAR(50) NOT NULL,

            review_score TINYINT NOT NULL,

            review_comment_title NVARCHAR(500) NULL,
            review_comment_message NVARCHAR(MAX) NULL,

            review_creation_date DATETIME2(0) NULL,
            review_answer_timestamp DATETIME2(0) NULL,

            CONSTRAINT PK_fact_order_reviews
                PRIMARY KEY (review_id, order_id),

            CONSTRAINT FK_reviews_orders
                FOREIGN KEY (order_id)
                REFERENCES dw.fact_orders(order_id),

            CONSTRAINT CK_review_score
                CHECK (review_score BETWEEN 1 AND 5)
        );
    END;

    -- Prevent accidental duplicate loading.
    IF EXISTS (SELECT 1 FROM dw.fact_order_reviews)
        THROW 50074, 'Reviews fact already populated.', 1;

    -- Insert cleaned review records.
    INSERT INTO dw.fact_order_reviews
    (
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp
    )
    SELECT
        LTRIM(RTRIM(review_id)),
        LTRIM(RTRIM(order_id)),

        TRY_CONVERT(TINYINT, review_score),

        NULLIF(LTRIM(RTRIM(review_comment_title)), ''),
        NULLIF(LTRIM(RTRIM(review_comment_message)), ''),

        TRY_CONVERT(
            DATETIME2(0), review_creation_date, 120
        ),

        TRY_CONVERT(
            DATETIME2(0), review_answer_timestamp, 120
        )

    FROM stg.order_reviews;

    -- Reconcile source and destination row counts.
    IF (
        SELECT COUNT(*) FROM dw.fact_order_reviews
    ) <> (
        SELECT COUNT(*) FROM stg.order_reviews
    )
        THROW 50075, 'Review row-count mismatch.', 1;

    -- Commit after all validations succeed.
    COMMIT TRANSACTION;

END TRY
BEGIN CATCH

    -- Roll back incomplete changes.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO

-- Validate the Customer Reviews Fact Table.
SELECT
    COUNT(*) AS Total_Reviews,

    COUNT(DISTINCT order_id) AS Orders_With_Reviews,

    CAST(AVG(CAST(review_score AS DECIMAL(10,2)))
        AS DECIMAL(10,2)) AS Average_Review_Score,

    SUM(CASE
        WHEN review_score <= 2 THEN 1
        ELSE 0
    END) AS Low_Rating_Reviews,

    SUM(CASE
        WHEN review_comment_title IS NULL THEN 1
        ELSE 0
    END) AS Missing_Review_Titles,

    SUM(CASE
        WHEN review_comment_message IS NULL THEN 1
        ELSE 0
    END) AS Missing_Review_Messages

FROM dw.fact_order_reviews;
GO
