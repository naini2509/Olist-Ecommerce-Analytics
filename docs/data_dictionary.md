# Olist E-Commerce Analytics — Data Dictionary

## 1. Purpose

This document describes the datasets, warehouse tables, reporting views, business metrics, and analytical definitions used in the Olist E-Commerce Intelligence project.

The goal is to provide a consistent reference for understanding the SQL Server data warehouse, Python analyses, and Power BI dashboard.

**Database:** `OlistEcommerceAnalytics`

**Source:** Brazilian E-Commerce Public Dataset by Olist

**Historical period:** 2016–2018

**Currency:** Brazilian Real (BRL / R$)

---

## 2. Source Datasets

Nine CSV datasets were used in this project.

| Source file | Records | Description |
|---|---:|---|
| `olist_customers_dataset.csv` | 99,441 | Customer identifiers and geographic information |
| `olist_orders_dataset.csv` | 99,441 | Orders, statuses, and fulfillment timestamps |
| `olist_order_items_dataset.csv` | 112,650 | Individual purchased items, sellers, prices, and freight |
| `olist_order_payments_dataset.csv` | 103,886 | Payment methods, installments, and recorded amounts |
| `olist_order_reviews_dataset.csv` | 99,224 | Customer reviews, ratings, and review timestamps |
| `olist_products_dataset.csv` | 32,951 | Product attributes and category information |
| `olist_sellers_dataset.csv` | 3,095 | Seller identifiers and locations |
| `olist_geolocation_dataset.csv` | 1,000,163 | ZIP-prefix geographic observations |
| `product_category_name_translation.csv` | 71 | Portuguese-to-English category translations |

**Important:** These datasets have different row-level meanings, or *grains*. Joining them without accounting for their one-to-many relationships can duplicate records and inflate monetary totals.

---

## 3. SQL Server Schemas

| Schema | Description |
|---|---|
| `stg` | Staging tables containing ingested source data |
| `dw` | Cleaned dimensional warehouse tables |
| `analytics` | Reporting views designed for business intelligence and statistical analysis |

The staging layer preserves source-level detail. Warehouse tables implement cleaned business structures, while analytical views provide reusable datasets for Power BI and Python.

---

## 4. Warehouse Dimension Tables

### 4.1 `dw.dim_customer`

**Grain:** One customer record identified by `customer_id`.

**Validated row count:** 99,441

| Column | Business definition |
|---|---|
| `customer_id` | Identifier for the customer record associated with an order |
| `customer_unique_id` | Identifier used to recognize the same purchaser across different orders |
| Customer city | Customer's reported city |
| Customer state | Two-character Brazilian state abbreviation |
| Customer ZIP prefix | Geographic ZIP-code prefix |

**Business rule:** `customer_id` and `customer_unique_id` are not interchangeable.

The dataset contains 99,441 customer records but **96,096 distinct purchasers**.

### 4.2 `dw.dim_product`

**Grain:** One product identified by `product_id`.

**Validated row count:** 32,951

| Column | Business definition |
|---|---|
| `product_id` | Unique product identifier |
| `product_category_name` | Original Portuguese product category |
| `product_category_english` | Standardized English product category |
| `category_mapping_status` | Translation or mapping classification |
| `product_name_length` | Length of the product name |
| `product_description_length` | Length of the product description |
| `product_photos_qty` | Number of product photos |
| `product_weight_g` | Product weight in grams |
| `product_length_cm` | Product length in centimeters |
| `product_height_cm` | Product height in centimeters |
| `product_width_cm` | Product width in centimeters |

**Data-quality note:** The source contains 610 products without an original category assignment. Supplementary translation overrides were also used for categories missing from the supplied translation file.

### 4.3 `dw.dim_seller`

**Grain:** One seller identified by `seller_id`.

**Validated row count:** 3,095

| Field | Business definition |
|---|---|
| Seller ID | Unique seller identifier |
| Seller city | Seller's reported city |
| Seller state | Brazilian state in which the seller is located |
| Seller ZIP prefix | Seller's geographic ZIP-code prefix |

### 4.4 `dw.dim_geography`

**Grain:** One representative geographic record per ZIP-code prefix.

**Validated row count:** 19,015

The geography dimension consolidates repeated source geolocation observations.

It supports geographic analysis using ZIP prefixes, representative coordinates, cities, and states.

---

## 5. Warehouse Fact Tables

### 5.1 `dw.fact_orders`

**Grain:** One row per order.

**Validated row count:** 99,441

Contains information about:

- Order identity.
- Customer association.
- Purchase date and order lifecycle.
- Order status.
- Promised and actual delivery timing.
- Delivery KPI eligibility.
- Whether a delivery was late.

### 5.2 `dw.fact_order_items`

**Grain:** One row per purchased order item.

**Validated row count:** 112,650

| Column | Data type | Business definition |
|---|---|---|
| `order_id` | Text | Order associated with the item |
| `order_item_id` | Integer | Item sequence within an order |
| `product_id` | Text | Purchased product |
| `seller_id` | Text | Seller fulfilling the item |
| `shipping_limit_date` | Datetime | Shipping deadline recorded in the dataset |
| `item_price_brl` | Decimal | Merchandise price of the item, excluding freight |
| `freight_value_brl` | Decimal | Recorded freight charge for the item |

**Validated totals:**

- Merchandise value: R$13,591,643.70
- Freight charges: R$2,251,909.54

### 5.3 `dw.fact_payments`

**Grain:** One payment record within an order.

**Validated row count:** 103,886

| Column | Business definition |
|---|---|
| `order_id` | Order associated with the payment |
| `payment_sequential` | Sequence number for payment records within an order |
| `payment_type` | Payment method |
| `payment_installments` | Recorded installment count |
| `payment_value_brl` | Recorded payment amount in BRL |

**Validated total payment value:** R$16,008,872.12

An order may have multiple payment records. Payment records must therefore be aggregated before joining with order-level or item-level financial summaries.

### 5.4 `dw.fact_order_reviews`

**Grain:** One review record.

**Validated row count:** 99,224

Contains review identifiers, order references, review scores, review text, and relevant review timestamps.

Some orders have multiple reviews.

For order-level satisfaction reporting, the latest answered review is selected using a deterministic ordering rule.

---

## 6. Analytical Reporting Views

### 6.1 `analytics.vw_order_overview`

**Power BI table name:** `Fact_Order_Overview`

**Grain:** One row per order.

**Validated row count:** 99,441

This is the primary table for order-level business reporting.

| Column | Definition |
|---|---|
| `order_id` | Unique order identifier |
| `customer_id` | Order-associated customer record |
| `customer_unique_id` | Purchaser identity across orders |
| `customer_state` | Customer's Brazilian state |
| `customer_city` | Customer's city |
| `purchase_date` | Date on which the order was purchased |
| `order_status` | Recorded order lifecycle status |
| `delivery_kpi_eligible` | Indicates whether the order is valid for delivery-rate analysis |
| `is_late` | Indicates whether an eligible delivery was late |
| `days_from_promise` | Difference between actual delivery and the promised date, in days |
| `item_count` | Number of items associated with the order |
| `seller_count` | Number of distinct sellers associated with the order |
| `item_gmv_brl` | Merchandise value of the order, excluding freight |
| `freight_brl` | Total recorded freight charges for the order |
| `item_and_freight_total_brl` | Merchandise value plus freight charges |
| `payment_record_count` | Number of recorded payments associated with the order |
| `payment_total_brl` | Sum of recorded payments for the order |
| `review_score` | Score from the selected review, when available |
| `low_rating_flag` | 1 for a 1–2-star review, 0 for another valid review, blank if unavailable |
| `reconciliation_status` | Classification of expected versus recorded payment amounts |

The Power BI model additionally includes a calculated `Delivery Timing` column and `Purchase Month` column for visualization.

### 6.2 `analytics.vw_category_order_items`

**Power BI table name:** `Category_Order_Items`

**Grain:** One order item.

**Validated row count:** 112,650

| Column | Definition |
|---|---|
| `order_id` | Order associated with the item |
| `order_item_id` | Item sequence within an order |
| `product_id` | Product identifier |
| `purchase_date` | Purchase date |
| `customer_state` | Customer's Brazilian state |
| `order_status` | Recorded order status |
| `product_category` | Standardized English product category or unknown/unmapped label |
| `item_price_brl` | Item merchandise value |
| `freight_value_brl` | Item freight charge |

This view supports interactive product-category reporting.

**Power BI relationship:**

`Fact_Order_Overview[order_id]` (1) → `Category_Order_Items[order_id]` (*)

The relationship is active and uses single-direction filtering.

### 6.3 `analytics.vw_category_gmv`

**Grain:** One standardized product category.

| Column | Definition |
|---|---|
| `product_category` | Product category |
| `total_items` | Count of order items in the category |
| `total_orders` | Distinct orders containing that category |
| `total_item_gmv_brl` | Merchandise value associated with the category |

This view provides an overall category summary.

For interactive geographic category analysis, the Power BI report uses the more detailed `Category_Order_Items` table.

### 6.4 `analytics.vw_payment_method_summary`

**Power BI table name:** `Payment_Method_Summary`

**Grain:** One payment method.

| Column | Definition |
|---|---|
| `payment_method` | Payment type, such as credit card or boleto |
| `payment_records` | Number of payment records using the method |
| `orders_using_method` | Distinct orders with at least one payment using the method |
| `total_payment_value_brl` | Total recorded payment amount using the method |

**Validated payment methods:**

| Payment method | Payment records | Value (BRL) |
|---|---:|---:|
| credit_card | 76,795 | 12,542,084.19 |
| boleto | 19,784 | 2,869,361.27 |
| voucher | 5,775 | 379,436.87 |
| debit_card | 1,529 | 217,989.79 |
| not_defined | 3 | 0.00 |

Because an order may use multiple payment methods, summing `orders_using_method` across categories does not necessarily produce the overall unique-order count.

### 6.5 `analytics.vw_delivery_satisfaction_features`

**Grain:** One delivery-KPI-eligible order with a selected valid review.

**Validated row count:** 95,824

This view supplies the Python statistical and classification analyses.

Its features include delivery timing, review outcomes, geographic information, purchase period, and selected order-level characteristics.

It supports consistent analysis without duplicating orders across multiple item, payment, or review records.

---

## 7. Business KPI Definitions

### Total Orders

Distinct count of `order_id`.

**Validated overall value:** 99,441

### Unique Purchasers

Distinct count of `customer_unique_id`.

**Validated overall value:** 96,096

### Item GMV

Sum of `item_gmv_brl`, excluding freight.

**Validated overall value:** R$13,591,643.70

Includes recorded merchandise amounts across all order statuses.

**Not equivalent to recognized revenue.**

### Average Order Value

Item GMV divided by the number of orders with associated merchandise items.

**Validated overall value:** R$137.75

The denominator is 98,666 orders with items, rather than all 99,441 orders. This distinction matters because some orders do not have item records.

### Total Recorded Payments

Sum of `payment_total_brl`.

**Validated overall value:** R$16,008,872.12

This reflects recorded customer payments, not net revenue or profit.

### Late Delivery Rate

\[
\text{Late Delivery Rate}=\frac{\text{Late Eligible Deliveries}}{\text{All Eligible Deliveries}}
\]

**Validated counts:**

- Eligible deliveries: 96,470
- Late deliveries: 6,534
- Overall rate: 6.77%

### Freight Share

\[
\text{Freight Share}=\frac{\text{Freight Charges}}{\text{Merchandise Value + Freight Charges}}
\]

This measures the share of recorded customer charges attributable to freight.

It does not measure the seller's internal shipping expenditure.

### Negative Review Rate

\[
\text{Negative Review Rate}=\frac{\text{Valid 1–2 Star Reviews}}{\text{All Valid Reviewed Orders}}
\]

Orders without valid reviews are excluded from the denominator.

### Average Review Score

Arithmetic mean of valid selected review scores.

Review scores range from 1 to 5.

---

## 8. Power BI Calculated Fields and Measures

The report includes these reusable calculations.

| Field or measure | Purpose |
|---|---|
| `Total Orders` | Counts distinct order IDs |
| `Total Item GMV` | Aggregates merchandise value |
| `Average Order Value` | Measures merchandise value per order containing items |
| `Total Recorded Payments` | Aggregates recorded customer payment amounts |
| `Late Delivery Rate` | Measures late-delivery percentage among eligible orders |
| `Freight Share (%)` | Measures freight as a percentage of merchandise-plus-freight charges |
| `Delivery Timing` | Categorizes eligible deliveries as Late or On Time |
| `Low Rating Rate (%)` | Calculates the share of valid reviews rated 1–2 stars |
| `Reviewed Orders` | Counts orders with nonblank review outcomes |
| `Average Review Score` | Calculates mean review score |
| `Late Reviewed Orders` | Counts valid reviewed late deliveries |
| `On-Time Reviewed Orders` | Counts valid reviewed on-time deliveries |
| `Confusion Matrix Cell Color` | Supplies conditional-formatting colors for the model confusion matrix |

All calculations are interpreted within their relevant Power BI filter context.

---

## 9. Delivery and Review Rules

### Delivery classifications

| Classification | Meaning |
|---|---|
| On Time | Eligible order delivered on or before the promised date |
| Late | Eligible order delivered after the promised date |
| Blank | Order excluded from delivery-performance analysis |

**Validated delivery counts:**

| Classification | Orders |
|---|---:|
| On Time | 89,936 |
| Late | 6,534 |
| Ineligible | 2,971 |
| Total | 99,441 |

### Reviewed delivery groups

| Metric | On Time | Late |
|---|---:|---:|
| Valid reviewed orders | 89,443 | 6,381 |
| Low-rated orders | 8,289 | 3,983 |
| Negative review rate | 9.27% | 62.42% |
| Average review score | 4.29 | 2.27 |

These denominators differ from all eligible deliveries because some delivered orders lack a valid selected review.

---

## 10. Payment Reconciliation Definitions

The reconciliation compares, at the order level:

**Expected charges:** Sum of merchandise item prices and freight charges.

**Recorded charges:** Sum of payment records.

| Status | Definition | Orders |
|---|---|---:|
| MATCH | Payment and expected charges agree within tolerance | 98,362 |
| MISSING_ITEMS | Recorded payment exists, but corresponding item records are missing | 775 |
| DIFFERENCE | Payment and expected charges differ beyond tolerance | 303 |
| MISSING_PAYMENTS | Item charges exist, but recorded payments are missing | 1 |

**Tolerance:** R$0.01

A reconciliation difference should be investigated before drawing conclusions about its financial cause.

---

## 11. Statistical and Machine Learning Fields

### Logistic regression inference

**Outcome:** Low customer rating, defined as 1 or 2 stars.

**Key explanatory variable:** Late delivery indicator.

**Adjusted odds ratio:** 17.23

**95% confidence interval:** 16.24–18.28

**p-value:** Less than 0.001

**Sample size:** 95,824 reviewed eligible orders.

The adjusted odds ratio represents an association in observational data. It is not a probability ratio or a causal effect.

### Retrospective classification evaluation

The Power BI report includes a static model-evaluation summary.

| Metric | Value |
|---|---:|
| Test observations | 19,165 |
| ROC-AUC | 0.6633 |
| Average Precision (AP) | 0.2660 |
| Precision | 28.55% |
| Recall | 37.06% |
| Validation-selected classification threshold | 0.1174 |

### `ML_Confusion_Matrix`

A disconnected Power BI table containing static holdout-test counts.

| Actual rating | Predicted rating | Order count |
|---|---|---:|
| Not Low | Not Low | 15,592 |
| Not Low | Low Rating | 1,719 |
| Low Rating | Not Low | 1,167 |
| Low Rating | Low Rating | 687 |

### `ML_Risk_Segments`

A disconnected Power BI table containing retrospective on-time-order subgroup evaluation.

| Risk segment | Negative review rate | Reviewed orders |
|---|---:|---:|
| All On-Time Orders | 8.35% | 18,508 |
| Highest-Risk 10% | 21.12% | 1,851 |

The highest-risk segment is a subset of the overall on-time group.

**Interpretation:** Approximately 2.53× concentration lift.

**Limitation:** The model uses realized delivery information and is not a validated pre-delivery prediction system.

---

## 12. Data Quality and Interpretation Notes

- Different tables have different grains and must not be joined indiscriminately.
- Some products have missing or unmapped categories.
- An order may have multiple items, payments, or reviews.
- Unique purchasers must be identified using `customer_unique_id`.
- Undelivered or ineligible orders must not be included in the late-delivery-rate denominator.
- Missing reviews must not be counted as nonnegative reviews.
- Historical months with sparse or incomplete coverage require careful interpretation.
- The monthly delivery trend uses January 2017 through August 2018.
- Item GMV, payment value, revenue, and profit are distinct financial concepts.
- Static Python model evaluation tables do not dynamically recalculate with Power BI slicers.
- Statistical associations are not evidence of causation.

## 13. Summary

This data dictionary establishes consistent definitions for the SQL Server warehouse, analytical views, Power BI measures, and Python statistical results.

It supports accurate metric interpretation, reproducible analysis, and transparent communication of the project's business findings.