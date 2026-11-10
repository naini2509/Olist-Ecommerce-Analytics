
# Project: Olist E-Commerce Analytics
# Purpose: Load product category translations into SQL Server.
# Source: product_category_name_translation.csv
# Target: stg.category_translation

from pathlib import Path
import pandas as pd
import pyodbc

# Locate the original category translation CSV.
PROJECT_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = (
    PROJECT_ROOT / "data" / "raw"
    / "product_category_name_translation.csv"
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

# Define the two expected source columns.
COLUMNS = [
    "product_category_name",
    "product_category_name_english",
]

# Build a parameterized INSERT statement.
column_names = ", ".join(f"[col]" for col in COLUMNS)
column_names = ", ".join(f"[{col}]" for col in COLUMNS)
placeholders = ", ".join("?" for _ in COLUMNS)

INSERT_SQL = (
    f"INSERT INTO stg.category_translation ({column_names}) "
    f"VALUES ({placeholders})"
)

# Confirm that the source CSV exists.
if not CSV_PATH.is_file():
    raise FileNotFoundError(f"Missing source CSV: {CSV_PATH}")

# Read all 71 records while preserving source text.
df = pd.read_csv(
    CSV_PATH,
    dtype=str,
    keep_default_na=False
)

# Validate the expected source schema and record count.
if list(df.columns) != COLUMNS:
    raise ValueError("Unexpected category translation columns.")

if len(df) != 71:
    raise ValueError(f"Expected 71 records, found {len(df)}.")

# Convert empty strings into SQL NULLs.
records = [
    tuple(None if value == "" else str(value) for value in row)
    for row in df.itertuples(index=False, name=None)
]

# Open a SQL Server transaction for safe insertion.
conn = pyodbc.connect(CONNECTION_STRING, autocommit=False)

try:
    cursor = conn.cursor()

    # Prevent accidental duplicate loading.
    cursor.execute("SELECT COUNT(*) FROM stg.category_translation")
    existing_rows = cursor.fetchone()[0]

    if existing_rows != 0:
        raise RuntimeError(
            f"stg.category_translation already has "
            f"{existing_rows} records. Load stopped."
        )

    # Use standard ODBC parameter binding.
    cursor.fast_executemany = False

    # Insert all category translations.
    cursor.executemany(INSERT_SQL, records)

    # Verify the destination count before committing.
    cursor.execute("SELECT COUNT(*) FROM stg.category_translation")
    sql_count = cursor.fetchone()[0]

    if sql_count != len(records):
        raise RuntimeError(
            f"Count mismatch: CSV={len(records)}, SQL={sql_count}"
        )

    # Commit the verified data.
    conn.commit()

    print("Category translation ingestion completed successfully!")
    print(f"Source records: {len(records)}")
    print(f"SQL Server records: {sql_count}")

except Exception:
    # Roll back if insertion or validation fails.
    conn.rollback()
    raise

finally:
    # Close the database connection.
    conn.close()
