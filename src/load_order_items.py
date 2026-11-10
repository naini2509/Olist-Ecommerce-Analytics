
# Project: Olist E-Commerce Analytics
# Purpose: Load order-item records from CSV into SQL Server.
# Source: olist_order_items_dataset.csv
# Target: stg.order_items

from pathlib import Path
import pandas as pd
import pyodbc

# Locate the source CSV relative to this Python script.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = PROJECT_ROOT / "data" / "raw" / "olist_order_items_dataset.csv"

# Configure our local SQL Server connection.
CONNECTION_STRING = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=Sindhu;"
    "DATABASE=OlistEcommerceAnalytics;"
    "Trusted_Connection=yes;"
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
)

# Define the expected columns in the original CSV.
COLUMNS = [
    "order_id",
    "order_item_id",
    "product_id",
    "seller_id",
    "shipping_limit_date",
    "price",
    "freight_value",
]

# Create a parameterized SQL INSERT statement.
column_names = ", ".join(f"[{column}]" for column in COLUMNS)
placeholders = ", ".join("?" for _ in COLUMNS)

INSERT_SQL = (
    f"INSERT INTO stg.order_items ({column_names}) "
    f"VALUES ({placeholders})"
)

# Load records in batches to control memory usage.
BATCH_SIZE = 5000
EXPECTED_ROWS = 112650

# Verify the CSV file exists before connecting to SQL Server.
if not CSV_PATH.is_file():
    raise FileNotFoundError(f"Source file not found: {CSV_PATH}")

# Open a transaction so failed loads do not leave partial records.
conn = pyodbc.connect(CONNECTION_STRING, autocommit=False)

try:
    cursor = conn.cursor()

    # Prevent accidental duplicate ingestion when rerunning the script.
    cursor.execute("SELECT COUNT(*) FROM stg.order_items")
    existing_rows = cursor.fetchone()[0]

    if existing_rows != 0:
        raise RuntimeError(
            f"stg.order_items already contains {existing_rows} rows. "
            "Loading stopped to prevent duplicates."
        )

    # Use standard parameter binding to avoid the ODBC
    # compatibility errors encountered during Orders ingestion.
    cursor.fast_executemany = False

    total_loaded = 0

    # Read the source file in batches while preserving raw text.
    for chunk in pd.read_csv(
        CSV_PATH,
        dtype=str,
        keep_default_na=False,
        chunksize=BATCH_SIZE
    ):

        # Stop if the CSV schema differs from our expected schema.
        if list(chunk.columns) != COLUMNS:
            raise ValueError("Unexpected columns in Order Items CSV.")

        # Convert each cell to a native Python string or None.
        # This also prevents NaN values from reaching pyodbc.
        records = [
            tuple(
                None if pd.isna(value) or value == ""
                else str(value)
                for value in row
            )
            for row in chunk.itertuples(index=False, name=None)
        ]

        # Insert the current batch into the staging table.
        cursor.executemany(INSERT_SQL, records)

        # Display ingestion progress.
        total_loaded += len(records)
        print(f"Inserted {total_loaded:,} order-item records")

    # Validate row counts before committing the transaction.
    cursor.execute("SELECT COUNT(*) FROM stg.order_items")
    sql_count = cursor.fetchone()[0]

    if sql_count != total_loaded:
        raise RuntimeError(
            f"Row-count mismatch: CSV={total_loaded}, SQL={sql_count}"
        )

    # Check against the original dataset profiling result.
    if total_loaded != EXPECTED_ROWS:
        raise RuntimeError(
            f"Expected {EXPECTED_ROWS:,} rows, "
            f"but loaded {total_loaded:,}."
        )

    # Commit only after all validation checks pass.
    conn.commit()

    print("\nOrder Items ingestion completed successfully!")
    print(f"Source records: {total_loaded:,}")
    print(f"SQL Server records: {sql_count:,}")

except Exception:
    # Roll back uncommitted inserts if any operation fails.
    conn.rollback()
    raise

finally:
    # Close the SQL Server connection.
    conn.close()
