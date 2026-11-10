
-- Project: Olist E-Commerce Analytics
-- Purpose: Build a geographic dimension with one row per ZIP prefix.
-- Source: stg.geolocation
-- Target: dw.dim_geography

USE OlistEcommerceAnalytics;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Validate that every geographic record has a ZIP prefix.
    IF EXISTS (
        SELECT 1
        FROM stg.geolocation
        WHERE NULLIF(
            LTRIM(RTRIM(geolocation_zip_code_prefix)), ''
        ) IS NULL
    )
        THROW 50030, 'Missing geographic ZIP prefixes.', 1;

    -- Create the dimension if it does not already exist.
    IF OBJECT_ID('dw.dim_geography', 'U') IS NULL
    BEGIN
        CREATE TABLE dw.dim_geography
        (
            zip_code_prefix NVARCHAR(10) NOT NULL PRIMARY KEY,
            city NVARCHAR(150) NULL,
            state NVARCHAR(10) NULL,
            latitude DECIMAL(10,6) NULL,
            longitude DECIMAL(10,6) NULL
        );
    END;

    -- Prevent accidental duplicate loading.
    IF EXISTS (SELECT 1 FROM dw.dim_geography)
        THROW 50031, 'Geography dimension already populated.', 1;

    ;WITH cleaned AS
    (
        -- Standardize text and convert coordinates.
        SELECT
            LTRIM(RTRIM(geolocation_zip_code_prefix))
                AS zip_code_prefix,

            NULLIF(
                LOWER(LTRIM(RTRIM(geolocation_city))), ''
            ) AS city,

            NULLIF(
                UPPER(LTRIM(RTRIM(geolocation_state))), ''
            ) AS state,

            TRY_CONVERT(FLOAT, geolocation_lat) AS latitude,
            TRY_CONVERT(FLOAT, geolocation_lng) AS longitude
        FROM stg.geolocation
    ),

    zip_codes AS
    (
        -- Retain all unique ZIP prefixes.
        SELECT DISTINCT zip_code_prefix
        FROM cleaned
    ),

    unique_coordinates AS
    (
        -- Remove repeated coordinate pairs before averaging.
        SELECT DISTINCT
            zip_code_prefix,
            latitude,
            longitude
        FROM cleaned
        WHERE latitude BETWEEN -90 AND 90
          AND longitude BETWEEN -180 AND 180
    ),

    coordinate_summary AS
    (
        -- Calculate a representative location per ZIP prefix.
        SELECT
            zip_code_prefix,
            AVG(latitude) AS latitude,
            AVG(longitude) AS longitude
        FROM unique_coordinates
        GROUP BY zip_code_prefix
    ),

    city_state_counts AS
    (
        -- Count occurrences of each city/state combination.
        SELECT
            zip_code_prefix,
            city,
            state,
            COUNT(*) AS occurrence_count
        FROM cleaned
        GROUP BY zip_code_prefix, city, state
    ),

    ranked_locations AS
    (
        -- Choose the most frequently observed location.
        SELECT
            zip_code_prefix,
            city,
            state,

            ROW_NUMBER() OVER (
                PARTITION BY zip_code_prefix
                ORDER BY
                    occurrence_count DESC,
                    state,
                    city
            ) AS location_rank

        FROM city_state_counts
    )

    -- Load one record per ZIP prefix.
    INSERT INTO dw.dim_geography
    (
        zip_code_prefix,
        city,
        state,
        latitude,
        longitude
    )
    SELECT
        z.zip_code_prefix,
        l.city,
        l.state,
        CAST(c.latitude AS DECIMAL(10,6)),
        CAST(c.longitude AS DECIMAL(10,6))

    FROM zip_codes AS z

    LEFT JOIN coordinate_summary AS c
        ON z.zip_code_prefix = c.zip_code_prefix

    LEFT JOIN ranked_locations AS l
        ON z.zip_code_prefix = l.zip_code_prefix
       AND l.location_rank = 1;

    -- Verify that all distinct ZIP prefixes were preserved.
    IF (
        SELECT COUNT(*) FROM dw.dim_geography
    ) <> (
        SELECT COUNT(DISTINCT geolocation_zip_code_prefix)
        FROM stg.geolocation
    )
        THROW 50032, 'Geography row-count mismatch.', 1;

    COMMIT TRANSACTION;

END TRY
BEGIN CATCH

    -- Roll back incomplete transformations on failure.
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
GO

-- Verify the completed Geography Dimension.
SELECT
    COUNT(*) AS Total_Geographic_Records,

    COUNT(DISTINCT zip_code_prefix) AS Unique_ZIP_Prefixes,

    SUM(CASE
        WHEN latitude IS NULL OR longitude IS NULL
        THEN 1 ELSE 0
    END) AS Missing_Coordinates,

    COUNT(DISTINCT state) AS States_Represented

FROM dw.dim_geography;
GO
