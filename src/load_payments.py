
# Project: Olist E-Commerce Analytics
# Purpose: Load payment records from CSV into SQL Server.
# Source: olist_order_payments_dataset.csv
# Target: stg.payments

from pathlib import Path
import pandas as pd
import pyodbc

# Locate the original CSV file.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = (
    PROJECT_ROOT / "data" / "raw"
    / "olist_order_payments_dataset.csv"
)

# Configure the local SQL Server connection.
CONNECTION_STRING = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=Sindhu;"
    "DATABASE=OlistEcommerceAnalytics;"
    "Trusted_Connection=yes;"
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
)

# Define the exact expected CSV columns.
COLUMNS = [
    "order_id",
    "payment_sequential",
    "payment_type",
    "payment_installments",
    "payment_value",
]

# Prepare a parameterized INSERT statement.
column_names = ", ".join(f"[{col}]" for col in COLUMNS)
placeholders = ", ".join("?" for _ in COLUMNS)

INSERT_SQL = (
    f"INSERT INTO stg.payments ({column_names}) "
    f"VALUES ({placeholders})"
)

# Configure batch size and expected record count.
BATCH_SIZE = 5000
EXPECTED_ROWS = 103886

# Verify the source file exists.
if not CSV_PATH.is_file():
    raise FileNotFoundError(f"CSV not found: {CSV_PATH}")

# Start a SQL Server transaction.
conn = pyodbc.connect(CONNECTION_STRING, autocommit=False)

try:
    cursor = conn.cursor()

    # Check whether payment data was previously loaded.
    cursor.execute("SELECT COUNT(*) FROM stg.payments")
    existing_rows = cursor.fetchone()[0]

    # Stop if the table already contains records.
    if existing_rows != 0:
        raise RuntimeError(
            f"stg.payments already contains {existing_rows} rows. "
            "Loading stopped to prevent duplicates."
        )

    # Use standard ODBC binding to avoid earlier driver errors.
    cursor.fast_executemany = False

    total_loaded = 0

    # Read the CSV file in batches.
    for chunk in pd.read_csv(
        CSV_PATH,
        dtype=str,
        keep_default_na=False,
        chunksize=BATCH_SIZE
    ):

        # Validate the source column structure.
        if list(chunk.columns) != COLUMNS:
            raise ValueError(
                "Unexpected columns in Payments CSV."
            )

        # Convert values to native strings or SQL NULLs.
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

        # Display progress after each batch.
        total_loaded += len(records)
        print(f"Inserted {total_loaded:,} payment records")

    # Validate SQL Server record count.
    cursor.execute("SELECT COUNT(*) FROM stg.payments")
    sql_count = cursor.fetchone()[0]

    # Compare the source and destination counts.
    if sql_count != total_loaded:
        raise RuntimeError(
            f"Count mismatch: CSV={total_loaded}, SQL={sql_count}"
        )

    # Check against the original dataset row count.
    if total_loaded != EXPECTED_ROWS:
        raise RuntimeError(
            f"Expected {EXPECTED_ROWS:,} rows, "
            f"but loaded {total_loaded:,}."
        )

    # Commit only after all validation checks succeed.
    conn.commit()

    print("\nPayments ingestion completed successfully!")
    print(f"Source records: {total_loaded:,}")
    print(f"SQL Server records: {sql_count:,}")

except Exception:
    # Roll back if any insertion or validation fails.
    conn.rollback()
    raise

finally:
    # Always close the SQL Server connection.
    conn.close()
