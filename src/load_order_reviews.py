
# Project: Olist E-Commerce Analytics
# Purpose: Load customer review records into SQL Server.
# Source: olist_order_reviews_dataset.csv
# Target: stg.order_reviews

from pathlib import Path
import pandas as pd
import pyodbc

# Locate the original source CSV file.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = (
    PROJECT_ROOT / "data" / "raw"
    / "olist_order_reviews_dataset.csv"
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

# Define the expected source columns in their original order.
COLUMNS = [
    "review_id",
    "order_id",
    "review_score",
    "review_comment_title",
    "review_comment_message",
    "review_creation_date",
    "review_answer_timestamp",
]

# Prepare a parameterized SQL INSERT statement.
column_names = ", ".join(f"[{column}]" for column in COLUMNS)
placeholders = ", ".join("?" for _ in COLUMNS)

INSERT_SQL = (
    f"INSERT INTO stg.order_reviews ({column_names}) "
    f"VALUES ({placeholders})"
)

# Configure the expected source count and batch size.
EXPECTED_ROWS = 99224
BATCH_SIZE = 2000

# Confirm that the source CSV exists before starting ingestion.
if not CSV_PATH.is_file():
    raise FileNotFoundError(f"CSV file not found: {CSV_PATH}")

# Open a transaction so incomplete loads can be rolled back.
conn = pyodbc.connect(CONNECTION_STRING, autocommit=False)

try:
    cursor = conn.cursor()

    # Prevent duplicate loading when the script is rerun.
    cursor.execute("SELECT COUNT(*) FROM stg.order_reviews")
    existing_rows = cursor.fetchone()[0]

    if existing_rows != 0:
        raise RuntimeError(
            f"stg.order_reviews already contains "
            f"{existing_rows:,} rows. "
            "Loading stopped to prevent duplicates."
        )

    # Use standard parameter binding for ODBC compatibility.
    cursor.fast_executemany = False

    total_loaded = 0

    # Read the review dataset in batches.
    for chunk in pd.read_csv(
        CSV_PATH,
        dtype=str,
        keep_default_na=False,
        chunksize=BATCH_SIZE,
        encoding="utf-8"
    ):

        # Validate that the source columns match the target.
        if list(chunk.columns) != COLUMNS:
            raise ValueError(
                "Unexpected columns in Order Reviews CSV."
            )

        # Convert missing or empty values to SQL NULL.
        # Preserve nonempty customer comments and rating text.
        records = [
            tuple(
                None if pd.isna(value) or value == ""
                else str(value)
                for value in row
            )
            for row in chunk.itertuples(index=False, name=None)
        ]

        # Insert each batch into the Reviews staging table.
        cursor.executemany(INSERT_SQL, records)

        # Display progress after each successful batch.
        total_loaded += len(records)
        print(f"Inserted {total_loaded:,} review records")

    # Reconcile the inserted count with SQL Server.
    cursor.execute("SELECT COUNT(*) FROM stg.order_reviews")
    sql_count = cursor.fetchone()[0]

    if sql_count != total_loaded:
        raise RuntimeError(
            f"Count mismatch: CSV={total_loaded}, SQL={sql_count}"
        )

    # Compare with the source profiling result.
    if total_loaded != EXPECTED_ROWS:
        raise RuntimeError(
            f"Expected {EXPECTED_ROWS:,} records, "
            f"but loaded {total_loaded:,}."
        )

    # Commit only after all validation checks pass.
    conn.commit()

    print("\nOrder Reviews ingestion completed successfully!")
    print(f"Source records: {total_loaded:,}")
    print(f"SQL Server records: {sql_count:,}")

except Exception:
    # Roll back the transaction if insertion or validation fails.
    conn.rollback()
    raise

finally:
    # Close the SQL Server connection.
    conn.close()
