
# Import pyodbc to connect Python to Microsoft SQL Server.
import pyodbc

# Define the SQL Server connection settings.
SERVER = "Sindhu"
DATABASE = "OlistEcommerceAnalytics"
DRIVER = "ODBC Driver 18 for SQL Server"

# Build the connection string using Windows Authentication.
# TrustServerCertificate is suitable for this local development setup.
connection_string = (
    f"DRIVER={{{DRIVER}}};"
    f"SERVER={SERVER};"
    f"DATABASE={DATABASE};"
    "Trusted_Connection=yes;"
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
    "Connection Timeout=10;"
)

# Open the connection and verify the target database.
try:
    with pyodbc.connect(connection_string) as conn:
        cursor = conn.cursor()

        # Query SQL Server to confirm the active database.
        cursor.execute("SELECT DB_NAME(), @@SERVERNAME")
        database_name, server_name = cursor.fetchone()

        print("SQL Server connection successful!")
        print("Connected Database:", database_name)
        print("Connected Server:", server_name)

except pyodbc.Error as error:
    # Print connection errors for troubleshooting.
    print("SQL Server connection failed.")
    print(error)
