
# Project: Olist E-Commerce Analytics
# Purpose: Load the Customers CSV into SQL Server staging.
# Source: olist_customers_dataset.csv
# Target: stg.customers

from pathlib import Path
import pandas as pd
import pyodbc

# Locate the project root and source CSV.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = (
    PROJECT_ROOT / "data" / "raw" / "olist_customers_dataset.csv"
)

# Configure your local SQL Server connection.
CONNECTION_STRING = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=Sindhu;"
    "DATABASE=OlistEcommerceAnalytics;"
    "Trusted_Connection=yes;"
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
)

# Define the exact source and target column order.
COLUMNS = [
    "customer_id",
    "customer_unique_id",
    "customer_zip_code_prefix",
    "customer_city",
    "customer_state",
]

# Build the parameterized SQL INSERT query.
column_names = ", ".join(f"[{col}]" for col in COLUMNS)
placeholders = ", ".join("?" for _ in COLUMNS)

INSERT_SQL = (
    f"INSERT INTO stg.customers ({column_names}) "
    f"VALUES ({placeholders})"
)

# Insert records in manageable batches.
BATCH_SIZE = 5000

# Stop if the source file cannot be found.
if not CSV_PATH.is_file():
    raise FileNotFoundError(f"Missing CSV file: {CSV_PATH}")

# Open a transactional SQL Server connection.
conn = pyodbc.connect(CONNECTION_STRING, autocommit=False)

try:
    cursor = conn.cursor()

    # Prevent reruns from accidentally duplicating customer records.
    cursor.execute("SELECT COUNT(*) FROM stg.customers")
    existing_rows = cursor.fetchone()[0]

    if existing_rows != 0:
        raise RuntimeError(
            f"stg.customers already contains {existing_rows} rows. "
            "Load stopped to avoid duplicate inserts."
        )

    # Use standard parameter binding for ODBC compatibility.
    cursor.fast_executemany = False

    total_loaded = 0

    # Read the CSV in batches while preserving identifiers as strings.
    for chunk in pd.read_csv(
        CSV_PATH,
        dtype=str,
        keep_default_na=False,
        chunksize=BATCH_SIZE
    ):

        # Validate the source schema before inserting records.
        if list(chunk.columns) != COLUMNS:
            raise ValueError(
                "Customer CSV columns do not match the expected schema."
            )

        # Convert all values into native Python strings or None.
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

        # Track ingestion progress.
        total_loaded += len(records)
        print(f"Inserted {total_loaded:,} customer records")

    # Reconcile the SQL Server count before committing.
    cursor.execute("SELECT COUNT(*) FROM stg.customers")
    sql_count = cursor.fetchone()[0]

    if sql_count != total_loaded:
        raise RuntimeError(
            f"Row-count mismatch: CSV={total_loaded}, SQL={sql_count}"
        )

    # Compare against the count from initial data profiling.
    if total_loaded != 99441:
        raise RuntimeError(
            f"Unexpected customer count: {total_loaded}"
        )

    # Commit the inserts only after successful validation.
    conn.commit()

    print("\nCustomer ingestion completed successfully!")
    print(f"Source records: {total_loaded:,}")
    print(f"SQL Server records: {sql_count:,}")

except Exception:
    # Roll back all uncommitted records when an error occurs.
    conn.rollback()
    raise

finally:
    # Always close the database connection.
    conn.close()
