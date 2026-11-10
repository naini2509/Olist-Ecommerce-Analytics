
# Project: Olist E-Commerce Analytics
# Purpose: Load raw geolocation CSV data into SQL Server.
# Source: olist_geolocation_dataset.csv
# Target: stg.geolocation

from pathlib import Path
import pandas as pd
import pyodbc

# Locate the project root and original source CSV.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = (
    PROJECT_ROOT / "data" / "raw"
    / "olist_geolocation_dataset.csv"
)

# Configure SQL Server using Windows Authentication.
CONNECTION_STRING = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=Sindhu;"
    "DATABASE=OlistEcommerceAnalytics;"
    "Trusted_Connection=yes;"
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
)

# Define the expected columns in their original order.
COLUMNS = [
    "geolocation_zip_code_prefix",
    "geolocation_lat",
    "geolocation_lng",
    "geolocation_city",
    "geolocation_state",
]

# Construct the parameterized SQL INSERT statement.
column_names = ", ".join(f"[{col}]" for col in COLUMNS)
placeholders = ", ".join("?" for _ in COLUMNS)

INSERT_SQL = (
    f"INSERT INTO stg.geolocation ({column_names}) "
    f"VALUES ({placeholders})"
)

# Configure ingestion settings for the larger dataset.
BATCH_SIZE = 10000
EXPECTED_ROWS = 1000163

# Verify the source file exists before connecting.
if not CSV_PATH.is_file():
    raise FileNotFoundError(
        f"Geolocation CSV not found: {CSV_PATH}"
    )

# Open a transaction to protect against partial imports.
conn = pyodbc.connect(
    CONNECTION_STRING,
    autocommit=False
)

try:
    cursor = conn.cursor()

    # Prevent duplicate imports when rerunning this script.
    cursor.execute("SELECT COUNT(*) FROM stg.geolocation")
    existing_rows = cursor.fetchone()[0]

    if existing_rows != 0:
        raise RuntimeError(
            f"stg.geolocation already contains "
            f"{existing_rows:,} records. "
            "Loading stopped to prevent duplicates."
        )

    # Use standard parameter binding because earlier
    # fast_executemany operations caused ODBC errors.
    cursor.fast_executemany = False

    total_loaded = 0

    # Read the source CSV in batches.
    # dtype=str also preserves ZIP-code leading zeros.
    for chunk in pd.read_csv(
        CSV_PATH,
        dtype=str,
        keep_default_na=False,
        chunksize=BATCH_SIZE,
        encoding="utf-8"
    ):

        # Validate the CSV schema before insertion.
        if list(chunk.columns) != COLUMNS:
            raise ValueError(
                "Unexpected columns in Geolocation CSV."
            )

        # Convert all values into native Python strings
        # or None for SQL NULLs.
        records = [
            tuple(
                None if pd.isna(value) or value == ""
                else str(value)
                for value in row
            )
            for row in chunk.itertuples(index=False, name=None)
        ]

        # Insert the batch into SQL Server staging.
        cursor.executemany(INSERT_SQL, records)

        # Update the imported record count.
        total_loaded += len(records)

        # Display progress periodically.
        if (
            total_loaded % 50000 == 0
            or total_loaded == EXPECTED_ROWS
        ):
            print(
                f"Inserted {total_loaded:,} "
                "geolocation records"
            )

    # Verify the source count before committing.
    if total_loaded != EXPECTED_ROWS:
        raise RuntimeError(
            f"Expected {EXPECTED_ROWS:,} records, "
            f"but processed {total_loaded:,}."
        )

    # Check the destination count before commit.
    cursor.execute(
        "SELECT COUNT(*) FROM stg.geolocation"
    )
    sql_count = cursor.fetchone()[0]

    if sql_count != total_loaded:
        raise RuntimeError(
            f"Count mismatch: "
            f"CSV={total_loaded}, SQL={sql_count}"
        )

    # Commit only after all records pass validation.
    conn.commit()

    print("\nGeolocation ingestion completed!")
    print(f"Source records: {total_loaded:,}")
    print(f"SQL Server records: {sql_count:,}")

except Exception:
    # Roll back all uncommitted rows on failure.
    conn.rollback()
    raise

finally:
    # Always close the database connection.
    conn.close()
