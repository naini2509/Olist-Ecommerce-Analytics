-- Retrieve the existing category GMV view definition.
USE OlistEcommerceAnalytics;
GO

SELECT
    OBJECT_DEFINITION(
        OBJECT_ID(N'analytics.vw_category_gmv')
    ) AS view_definition;