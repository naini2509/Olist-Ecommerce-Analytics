
-- Project: Olist E-Commerce Analytics
-- Purpose: Investigate the increase in missing review text
-- between staging and the cleaned warehouse.

USE OlistEcommerceAnalytics;
GO

-- Count missing and whitespace-only review titles/messages
-- in the original staging data.
SELECT
    SUM(CASE
        WHEN review_comment_title IS NULL
        THEN 1 ELSE 0
    END) AS Original_Null_Titles,

    SUM(CASE
        WHEN review_comment_title IS NOT NULL
         AND LTRIM(RTRIM(review_comment_title)) = ''
        THEN 1 ELSE 0
    END) AS Blank_Only_Titles,

    SUM(CASE
        WHEN review_comment_message IS NULL
        THEN 1 ELSE 0
    END) AS Original_Null_Messages,

    SUM(CASE
        WHEN review_comment_message IS NOT NULL
         AND LTRIM(RTRIM(review_comment_message)) = ''
        THEN 1 ELSE 0
    END) AS Blank_Only_Messages

FROM stg.order_reviews;
GO
