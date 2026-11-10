
# Project: Olist E-Commerce Analytics
# Purpose: Load the original Products CSV into SQL Server.
# Source: olist_products_dataset.csv
# Target: stg.products

from pathlib import Path
import pandas as pd
import pyodbc

# Identify the project directory and source CSV file.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = (
    PROJECT_ROOT / "data" / "raw"
    / "olist_products_dataset.csv"
)

# Configure SQL Server connection using Windows Authentication.
CONNECTION_STRING = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=Sindhu;"
    "DATABASE=OlistEcommerceAnalytics;"
    "Trusted_Connection=yes;"
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
)

# Preserve the source column names and their original order.
COLUMNS = [
    "product_id",
    "product_category_name",
    "product_name_lenght",
    "product_description_lenght",
    "product_photos_qty",
    "product_weight_g",
    "product_length_cm",
    "product_height_cm",
    "product_width_cm"
]

# Build a parameterized INSERT statement.
column_names = ", ".join(f"[{col}]" for col in COLUMNS)
placeholders = ", ".join("?" for _ in COLUMNS)

INSERT_SQL = (
    f"INSERT INTO stg.products ({column_names}) "
    f"VALUES ({placeholders})"
)

# Define batch size and expected source row count.
BATCH_SIZE = 5000
EXPECTED_ROWS = 32951

# Confirm the CSV file is available.
if not CSV_PATH.is_file():
    raise FileNotFoundError(f"CSV file not found: {CSV_PATH}")

# Open a transaction to avoid partially committed loads.
conn = pyodbc.connect(CONNECTION_STRING, autocommit=False)

try:
    cursor = conn.cursor()

    # Prevent duplicate ingestion if the script runs again.
    cursor.execute("SELECT COUNT(*) FROM stg.products")
    existing_rows = cursor.fetchone()[0]

    if existing_rows != 0:
        raise RuntimeError(
            f"stg.products already contains {existing_rows} rows. "
            "Loading stopped to prevent duplicates."
        )

    # Use standard parameter binding for ODBC compatibility.
    cursor.fast_executemany = False

    total_loaded = 0

    # Read the source CSV in batches.
    for chunk in pd.read_csv(
        CSV_PATH,
        dtype=str,
        keep_default_na=False,
        chunksize=BATCH_SIZE
    ):

        # Verify that source columns match the staging table.
        if list(chunk.columns) != COLUMNS:
            raise ValueError(
                "Product CSV columns do not match the expected schema."
            )

        # Convert source values to native strings or SQL NULL.
        # Keep all original nonmissing values unchanged.
        records = [
            tuple(
                None if pd.isna(value) or value == ""
                else str(value)
                for value in row
            )
            for row in chunk.itertuples(index=False, name=None)
        ]

        # Insert the current batch into SQL Server.
        cursor.executemany(INSERT_SQL, records)

        # Display the number of imported records.
        total_loaded += len(records)
        print(f"Inserted {total_loaded:,} product records")

    # Validate the SQL Server row count before committing.
    cursor.execute("SELECT COUNT(*) FROM stg.products")
    sql_count = cursor.fetchone()[0]

    if sql_count != total_loaded:
        raise RuntimeError(
            f"Row-count mismatch: CSV={total_loaded}, SQL={sql_count}"
        )

    # Compare against the initial dataset profiling result.
    if total_loaded != EXPECTED_ROWS:
        raise RuntimeError(
            f"Expected {EXPECTED_ROWS:,} records, "
            f"but loaded {total_loaded:,}."
        )

    # Commit only when all checks pass.
    conn.commit()

    print("\nProducts ingestion completed successfully!")
    print(f"Source records: {total_loaded:,}")
    print(f"SQL Server records: {sql_count:,}")

except Exception:
    # Roll back changes if insertion or validation fails.
    conn.rollback()
    raise

finally:
    # Always close the database connection.
    conn.close()
