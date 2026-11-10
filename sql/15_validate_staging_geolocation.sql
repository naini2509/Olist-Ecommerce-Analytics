
-- Project: Olist E-Commerce Analytics
-- Purpose: Validate Geolocation staging data.

USE OlistEcommerceAnalytics;
GO

-- Check total records, ZIP prefixes, and missing values.
SELECT
    COUNT(*) AS Total_Geolocation_Records,

    COUNT(DISTINCT geolocation_zip_code_prefix)
        AS Unique_ZIP_Prefixes,

    SUM(
        CASE
            WHEN geolocation_zip_code_prefix IS NULL
            THEN 1 ELSE 0
        END
    ) AS Missing_ZIP_Prefixes,

    SUM(
        CASE
            WHEN TRY_CONVERT(FLOAT, geolocation_lat) IS NULL
              OR TRY_CONVERT(FLOAT, geolocation_lng) IS NULL
            THEN 1 ELSE 0
        END
    ) AS Invalid_Coordinates

FROM stg.geolocation;
GO

-- Count completely duplicate geolocation records.
-- Preserve all records in staging.
WITH DuplicateGroups AS
(
    SELECT
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state,
        COUNT(*) AS Record_Count
    FROM stg.geolocation
    GROUP BY
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
)
SELECT
    SUM(Record_Count - 1) AS Duplicate_Rows
FROM DuplicateGroups;
GO
