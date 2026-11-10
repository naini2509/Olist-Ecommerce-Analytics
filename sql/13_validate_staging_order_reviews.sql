
-- Project: Olist E-Commerce Analytics
-- Purpose: Validate the imported Order Reviews dataset.

USE OlistEcommerceAnalytics;
GO

-- Check row counts, missing comments, and rating validity.
SELECT
    COUNT(*) AS Total_Reviews,

    COUNT(DISTINCT order_id) AS Orders_With_Reviews,

    SUM(CASE
        WHEN review_comment_title IS NULL
        THEN 1 ELSE 0
    END) AS Missing_Review_Titles,

    SUM(CASE
        WHEN review_comment_message IS NULL
        THEN 1 ELSE 0
    END) AS Missing_Review_Messages,

    SUM(CASE
        WHEN TRY_CONVERT(INT, review_score) NOT BETWEEN 1 AND 5
          OR review_score IS NULL
        THEN 1 ELSE 0
    END) AS Invalid_Review_Scores

FROM stg.order_reviews;
GO

-- Check duplicate review_id + order_id combinations.
SELECT COUNT(*) AS Duplicate_Review_Keys
FROM (
    SELECT review_id, order_id
    FROM stg.order_reviews
    GROUP BY review_id, order_id
    HAVING COUNT(*) > 1
) AS duplicate_groups;
GO

-- Identify orders with multiple review records.
SELECT COUNT(*) AS Orders_With_Multiple_Reviews
FROM (
    SELECT order_id
    FROM stg.order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) AS multi_review_orders;
GO
