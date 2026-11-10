
import os
import unittest
from decimal import Decimal

import pyodbc


class TestOlistDataQuality(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # Connect to the existing SQL Server warehouse.
        # Windows Authentication avoids storing passwords in code.
        server = os.getenv("OLIST_SQL_SERVER", "Sindhu")
        database = "OlistEcommerceAnalytics"

        cls.conn = pyodbc.connect(
            f"DRIVER={{ODBC Driver 18 for SQL Server}};"
            f"SERVER={server};"
            f"DATABASE={database};"
            "Trusted_Connection=yes;"
            "Encrypt=yes;"
            "TrustServerCertificate=yes;",
            timeout=10
        )

    @classmethod
    def tearDownClass(cls):
        # Close the database connection after all tests finish.
        cls.conn.close()

    @classmethod
    def get_value(cls, query):
        # Execute a SQL query and return its first value.
        cursor = cls.conn.cursor()
        cursor.execute(query)
        result = cursor.fetchone()[0]
        cursor.close()
        return result

    def test_source_record_counts(self):
        # Verify the warehouse has the expected record counts.
        expected_counts = {
            "dw.fact_orders": 99441,
            "dw.fact_order_items": 112650,
            "dw.fact_payments": 103886,
            "dw.dim_product": 32951,
            "dw.dim_seller": 3095,
        }

        for table, expected in expected_counts.items():
            with self.subTest(table=table):
                actual = self.get_value(
                    f"SELECT COUNT(*) FROM {table}"
                )
                self.assertEqual(actual, expected)

    def test_unique_order_ids(self):
        # Every order must appear exactly once in fact_orders.
        total_orders = self.get_value(
            "SELECT COUNT(*) FROM dw.fact_orders"
        )

        unique_orders = self.get_value(
            "SELECT COUNT(DISTINCT order_id) "
            "FROM dw.fact_orders"
        )

        self.assertEqual(total_orders, unique_orders)

    def test_total_item_gmv(self):
        # Validate merchandise value across all order items.
        actual = self.get_value(
            "SELECT SUM(item_price_brl) "
            "FROM dw.fact_order_items"
        )

        expected = Decimal("13591643.70")
        self.assertEqual(Decimal(str(actual)), expected)

    def test_total_recorded_payments(self):
        # Validate all recorded customer payment amounts.
        actual = self.get_value(
            "SELECT SUM(payment_value_brl) "
            "FROM dw.fact_payments"
        )

        expected = Decimal("16008872.12")
        self.assertEqual(Decimal(str(actual)), expected)


if __name__ == "__main__":
    unittest.main()
