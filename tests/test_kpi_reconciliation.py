
"""
Automated KPI and reporting-view validation for Olist Analytics.

Tests compare SQL Server analytical views against validated
warehouse totals and business rules.
"""

import os
import unittest
from decimal import Decimal

import pyodbc


class TestOlistKPIReconciliation(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # Connect to the existing local SQL Server database.
        server = os.getenv("OLIST_SQL_SERVER", "Sindhu")

        cls.conn = pyodbc.connect(
            "DRIVER={ODBC Driver 18 for SQL Server};"
            f"SERVER={server};"
            "DATABASE=OlistEcommerceAnalytics;"
            "Trusted_Connection=yes;"
            "Encrypt=yes;"
            "TrustServerCertificate=yes;",
            timeout=10,
        )

    @classmethod
    def tearDownClass(cls):
        # Close the SQL Server connection after testing.
        cls.conn.close()

    @classmethod
    def fetch_one(cls, sql):
        # Execute a query and return its first result row.
        cursor = cls.conn.cursor()
        cursor.execute(sql)
        row = cursor.fetchone()
        cursor.close()
        return row

    def test_order_overview_financial_totals(self):
        # The order-level reporting view must preserve
        # item GMV and recorded payments without duplication.
        row = self.fetch_one("""
            SELECT
                COUNT(*) AS orders,
                SUM(item_gmv_brl) AS item_gmv,
                SUM(payment_total_brl) AS payments
            FROM analytics.vw_order_overview;
        """)

        self.assertEqual(row[0], 99441)
        self.assertEqual(
            Decimal(str(row[1])),
            Decimal("13591643.70")
        )
        self.assertEqual(
            Decimal(str(row[2])),
            Decimal("16008872.12")
        )

    def test_delivery_kpi_counts(self):
        # Verify the population used for the late-delivery KPI.
        row = self.fetch_one("""
            SELECT
                SUM(CASE
                    WHEN delivery_kpi_eligible = 1
                    THEN 1 ELSE 0
                END) AS eligible_orders,

                SUM(CASE
                    WHEN delivery_kpi_eligible = 1
                     AND is_late = 1
                    THEN 1 ELSE 0
                END) AS late_orders
            FROM analytics.vw_order_overview;
        """)

        self.assertEqual(row[0], 96470)
        self.assertEqual(row[1], 6534)

        # Confirm the KPI is approximately 6.77%.
        self.assertAlmostEqual(
            row[1] / row[0] * 100,
            6.77,
            places=2
        )

    def test_reviewed_delivery_counts(self):
        # Check reviewed, delivery-eligible orders and
        # the number with negative customer ratings.
        row = self.fetch_one("""
            SELECT
                SUM(CASE
                    WHEN delivery_kpi_eligible = 1
                     AND low_rating_flag IS NOT NULL
                    THEN 1 ELSE 0
                END) AS reviewed_orders,

                SUM(CASE
                    WHEN delivery_kpi_eligible = 1
                     AND low_rating_flag = 1
                    THEN 1 ELSE 0
                END) AS negative_reviews
            FROM analytics.vw_order_overview;
        """)

        self.assertEqual(row[0], 95824)
        self.assertEqual(row[1], 12272)

    def test_payment_reconciliation_statuses(self):
        # Each order must belong to one reconciliation category.
        cursor = self.conn.cursor()

        cursor.execute("""
            SELECT reconciliation_status, COUNT(*)
            FROM analytics.vw_order_overview
            GROUP BY reconciliation_status;
        """)

        actual = {
            status: count
            for status, count in cursor.fetchall()
        }

        cursor.close()

        expected = {
            "MATCH": 98362,
            "MISSING_ITEMS": 775,
            "DIFFERENCE": 303,
            "MISSING_PAYMENTS": 1,
        }

        self.assertEqual(actual, expected)
        self.assertEqual(sum(actual.values()), 99441)

    def test_payment_method_summary(self):
        # Check that the payment-method summary reconciles
        # to the source payment fact table.
        row = self.fetch_one("""
            SELECT
                SUM(payment_records),
                SUM(total_payment_value_brl)
            FROM analytics.vw_payment_method_summary;
        """)

        self.assertEqual(row[0], 103886)
        self.assertEqual(
            Decimal(str(row[1])),
            Decimal("16008872.12")
        )

    def test_category_order_item_totals(self):
        # Verify that the interactive category view retains
        # every order item and its merchandise value.
        row = self.fetch_one("""
            SELECT
                COUNT(*),
                SUM(item_price_brl)
            FROM analytics.vw_category_order_items;
        """)

        self.assertEqual(row[0], 112650)
        self.assertEqual(
            Decimal(str(row[1])),
            Decimal("13591643.70")
        )


if __name__ == "__main__":
    unittest.main()
