
-- Project: Olist E-Commerce Analytics
-- Purpose: Compare the relationship between late deliveries
-- and negative reviews across customer states.
-- Grain: One eligible delivered order with one selected review.

USE OlistEcommerceAnalytics;
GO

-- Select the latest review for each order.
WITH ranked_reviews AS
(
    SELECT
        order_id,
        review_id,
        review_score,

        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY
                review_answer_timestamp DESC,
                review_creation_date DESC,
                review_id DESC
        ) AS rn

    FROM dw.fact_order_reviews
),

-- Combine delivery outcomes, customer geography,
-- and the selected order-level review.
order_analysis AS
(
    SELECT
        o.order_id,
        c.customer_state,
        o.is_late,

        CASE
            WHEN r.review_score <= 2 THEN 1
            ELSE 0
        END AS low_rating_flag

    FROM dw.fact_orders AS o

    INNER JOIN dw.dim_customer AS c
        ON o.customer_id = c.customer_id

    INNER JOIN ranked_reviews AS r
        ON o.order_id = r.order_id
       AND r.rn = 1

    -- Include only orders with observed delivery outcomes.
    WHERE o.delivery_kpi_eligible = 1
),

-- Aggregate reviewed orders by state.
regional_summary AS
(
    SELECT
        customer_state,

        -- Count on-time and late reviewed orders separately.
        SUM(CASE
            WHEN is_late = 0 THEN 1 ELSE 0
        END) AS on_time_orders,

        SUM(CASE
            WHEN is_late = 1 THEN 1 ELSE 0
        END) AS late_orders,

        -- Calculate the low-rating rate within each group.
        AVG(CASE
            WHEN is_late = 0
            THEN CAST(low_rating_flag AS FLOAT)
        END) AS on_time_low_rating_rate,

        AVG(CASE
            WHEN is_late = 1
            THEN CAST(low_rating_flag AS FLOAT)
        END) AS late_low_rating_rate

    FROM order_analysis
    GROUP BY customer_state
)

-- Compare observed low-rating rates within each state.
SELECT
    customer_state,

    on_time_orders,
    late_orders,

    CAST(
        on_time_low_rating_rate * 100
        AS DECIMAL(10,2)
    ) AS On_Time_Low_Rating_Pct,

    CAST(
        late_low_rating_rate * 100
        AS DECIMAL(10,2)
    ) AS Late_Low_Rating_Pct,

    CAST(
        (late_low_rating_rate - on_time_low_rating_rate) * 100
        AS DECIMAL(10,2)
    ) AS Risk_Difference_PP

FROM regional_summary

-- Apply minimum sample-size thresholds to avoid
-- reporting unstable comparisons from tiny groups.
WHERE on_time_orders >= 100
  AND late_orders >= 30

ORDER BY Risk_Difference_PP DESC;
GO
