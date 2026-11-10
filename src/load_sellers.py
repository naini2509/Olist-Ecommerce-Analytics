
# Project: Olist E-Commerce Analytics
# Purpose: Load seller records into SQL Server staging.
# Source: olist_sellers_dataset.csv
# Target: stg.sellers

from pathlib import Path
import pandas as pd
import pyodbc

# Locate the source file relative to this script.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = PROJECT_ROOT / "data" / "raw" / "olist_sellers_dataset.csv"

# Connect to the local SQL Server instance using Windows Authentication.
CONNECTION_STRING = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=Sindhu;"
    "DATABASE=OlistEcommerceAnalytics;"
    "Trusted_Connection=yes;"
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
)

# Preserve the exact source column names and order.
COLUMNS = [
    "seller_id",
    "seller_zip_code_prefix",
    "seller_city",
    "seller_state",
]

# Construct a parameterized INSERT statement.
column_names = ", ".join(f"[{column}]" for column in COLUMNS)
placeholders = ", ".join("?" for _ in COLUMNS)

INSERT_SQL = (
    f"INSERT INTO stg.sellers ({column_names}) "
    f"VALUES ({placeholders})"
)

# Define the source row-count expectation and batch size.
EXPECTED_ROWS = 3095
BATCH_SIZE = 1000

# Confirm that the original Sellers CSV is available.
if not CSV_PATH.is_file():
    raise FileNotFoundError(f"Missing source file: {CSV_PATH}")

# Open a transaction so all rows commit together.
conn = pyodbc.connect(CONNECTION_STRING, autocommit=False)

try:
    cursor = conn.cursor()

    # Avoid duplicating records if the script runs again.
    cursor.execute("SELECT COUNT(*) FROM stg.sellers")
    existing_rows = cursor.fetchone()[0]

    if existing_rows != 0:
        raise RuntimeError(
            f"stg.sellers already contains {existing_rows} rows. "
            "Loading stopped to prevent duplicates."
        )

    # Use standard ODBC parameter binding to avoid previous issues.
    cursor.fast_executemany = False

    total_loaded = 0

    # Read the source CSV in small batches.
    for chunk in pd.read_csv(
        CSV_PATH,
        dtype=str,
        keep_default_na=False,
        chunksize=BATCH_SIZE
    ):

        # Check the column names before importing.
        if list(chunk.columns) != COLUMNS:
            raise ValueError("Unexpected columns in Sellers CSV.")

        # Convert each value to a native Python string or SQL NULL.
        records = [
            tuple(
                None if pd.isna(value) or value == ""
                else str(value)
                for value in row
            )
            for row in chunk.itertuples(index=False, name=None)
        ]

        # Insert the current batch into the SQL Server staging table.
        cursor.executemany(INSERT_SQL, records)

        # Display ingestion progress.
        total_loaded += len(records)
        print(f"Inserted {total_loaded:,} seller records")

    # Validate the imported row count before committing.
    cursor.execute("SELECT COUNT(*) FROM stg.sellers")
    sql_count = cursor.fetchone()[0]

    if sql_count != total_loaded:
        raise RuntimeError(
            f"Count mismatch: CSV={total_loaded}, SQL={sql_count}"
        )

    if total_loaded != EXPECTED_ROWS:
        raise RuntimeError(
            f"Expected {EXPECTED_ROWS:,} records, "
            f"but loaded {total_loaded:,}."
        )

    # Commit after successful validation.
    conn.commit()

    print("\nSellers ingestion completed successfully!")
    print(f"Source records: {total_loaded:,}")
    print(f"SQL Server records: {sql_count:,}")

except Exception:
    # Roll back uncommitted inserts if any operation fails.
    conn.rollback()
    raise

finally:
    # Close the SQL Server connection.
    conn.close()
