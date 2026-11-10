
-- Project: Olist E-Commerce Analytics
-- Purpose: Compare customer satisfaction between
-- on-time and late deliveries.
-- Grain: One eligible delivered order with one selected review.

USE OlistEcommerceAnalytics;
GO

-- Rank multiple reviews for the same order.
WITH ranked_reviews AS
(
    SELECT
        order_id,
        review_id,
        review_score,
        review_creation_date,
        review_answer_timestamp,

        -- Select the latest answered review per order.
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY
                review_answer_timestamp DESC,
                review_creation_date DESC,
                review_id DESC
        ) AS review_rank

    FROM dw.fact_order_reviews
),

-- Join each eligible order to at most one review.
order_satisfaction AS
(
    SELECT
        o.order_id,
        o.is_late,
        r.review_score

    FROM dw.fact_orders AS o

    INNER JOIN ranked_reviews AS r
        ON o.order_id = r.order_id
       AND r.review_rank = 1

    -- Include only orders with known delivery outcomes.
    WHERE o.delivery_kpi_eligible = 1
),

-- Calculate satisfaction metrics by delivery status.
satisfaction_summary AS
(
    SELECT
        CASE
            WHEN is_late = 1 THEN 'Late Delivery'
            ELSE 'On-Time Delivery'
        END AS Delivery_Status,

        COUNT(*) AS Total_Reviewed_Orders,

        CAST(
            AVG(CAST(review_score AS DECIMAL(10,2)))
            AS DECIMAL(10,2)
        ) AS Average_Review_Score,

        SUM(
            CASE
                WHEN review_score <= 2 THEN 1
                ELSE 0
            END
        ) AS Low_Rating_Orders,

        CAST(
            100.0 * SUM(
                CASE
                    WHEN review_score <= 2 THEN 1
                    ELSE 0
                END
            ) / NULLIF(COUNT(*), 0)
            AS DECIMAL(10,2)
        ) AS Low_Rating_Percentage

    FROM order_satisfaction

    GROUP BY is_late
)

-- Display the final comparison.
SELECT
    Delivery_Status,
    Total_Reviewed_Orders,
    Average_Review_Score,
    Low_Rating_Orders,
    Low_Rating_Percentage

FROM satisfaction_summary

ORDER BY
    CASE
        WHEN Delivery_Status = 'On-Time Delivery' THEN 1
        ELSE 2
    END;
GO
