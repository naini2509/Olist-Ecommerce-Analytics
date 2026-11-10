
-- Project: Olist E-Commerce Analytics
-- Purpose: Create the Order Reviews staging table.
-- Source: olist_order_reviews_dataset.csv

USE OlistEcommerceAnalytics;
GO

-- Create the staging table only if it does not exist.
IF OBJECT_ID('stg.order_reviews', 'U') IS NULL
BEGIN
    CREATE TABLE stg.order_reviews
    (
        review_id NVARCHAR(50) NULL,
        order_id NVARCHAR(50) NULL,
        review_score NVARCHAR(10) NULL,
        review_comment_title NVARCHAR(500) NULL,
        review_comment_message NVARCHAR(MAX) NULL,
        review_creation_date NVARCHAR(30) NULL,
        review_answer_timestamp NVARCHAR(30) NULL
    );
END;
GO

-- Verify the seven columns and their data types.
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'stg'
  AND TABLE_NAME = 'order_reviews'
ORDER BY ORDINAL_POSITION;
GO

-- Verify that the staging table is initially empty.
SELECT COUNT(*) AS Total_Review_Records
FROM stg.order_reviews;
GO
