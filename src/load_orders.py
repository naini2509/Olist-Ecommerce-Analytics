
# Project: Olist E-Commerce Analytics
# Purpose: Load the raw Orders CSV into SQL Server.
# Target table: stg.orders

from pathlib import Path
import pandas as pd
import pyodbc

# Locate the project directory and source CSV.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = (
    PROJECT_ROOT / "data" / "raw" / "olist_orders_dataset.csv"
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

# List the exact columns expected in our staging table.
COLUMNS = [
    "order_id",
    "customer_id",
    "order_status",
    "order_purchase_timestamp",
    "order_approved_at",
    "order_delivered_carrier_date",
    "order_delivered_customer_date",
    "order_estimated_delivery_date",
]

# Build a parameterized INSERT statement.
# Placeholders protect values from SQL injection.
column_list = ", ".join(COLUMNS)
placeholders = ", ".join(["?"] * len(COLUMNS))

INSERT_SQL = (
    f"INSERT INTO stg.orders ({column_list}) "
    f"VALUES ({placeholders})"
)

# Load 5,000 rows per batch to manage memory.
BATCH_SIZE = 5000

# Confirm the source file exists before loading.
if not CSV_PATH.is_file():
    raise FileNotFoundError(f"CSV file not found: {CSV_PATH}")

# Connect to SQL Server with transactions enabled.
conn = pyodbc.connect(CONNECTION_STRING, autocommit=False)

try:
    cursor = conn.cursor()

    # Prevent accidental duplicate loading on reruns.
    cursor.execute("SELECT COUNT(*) FROM stg.orders")
    existing_rows = cursor.fetchone()[0]

    if existing_rows != 0:
        raise RuntimeError(
            f"stg.orders already has {existing_rows} rows. "
            "Load stopped to prevent duplicate records."
        )

    # Use standard parameter binding to avoid potential
    # ODBC batch-insertion compatibility issues.
    cursor.fast_executemany = False

    total_loaded = 0

    # Read the CSV in manageable chunks.
    for chunk in pd.read_csv(
        CSV_PATH,
        dtype=str,
        keep_default_na=False,
        chunksize=BATCH_SIZE
    ):

        # Confirm that source columns match our schema.
        if list(chunk.columns) != COLUMNS:
            raise ValueError("CSV columns do not match the staging schema.")


        # Convert every CSV value to a native Python string.
        # Preserve missing or empty values as SQL NULL.
        # This prevents pandas values such as NaN from being
        # passed to pyodbc as invalid floating-point values.

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

        # Track loading progress.
        total_loaded += len(records)
        print(f"Inserted {total_loaded:,} records")

    # Verify the table count before committing.
    cursor.execute("SELECT COUNT(*) FROM stg.orders")
    sql_count = cursor.fetchone()[0]

    if sql_count != total_loaded:
        raise RuntimeError(
            f"Count mismatch: Python={total_loaded}, "
            f"SQL Server={sql_count}"
        )

    # Verify against our previously profiled source count.
    if total_loaded != 99441:
        raise RuntimeError(
            f"Unexpected source count: {total_loaded}"
        )

    # Commit only after all records pass validation.
    conn.commit()

    print("\nData ingestion completed successfully!")
    print(f"Source rows: {total_loaded:,}")
    print(f"SQL Server rows: {sql_count:,}")

except Exception:
    # Undo uncommitted inserts if anything fails.
    conn.rollback()
    raise

finally:
    # Close the database connection.
    conn.close()
