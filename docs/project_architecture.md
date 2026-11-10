# Olist E-Commerce Analytics — Project Architecture

## 1. Architecture Overview

The Olist E-Commerce Analytics project is an end-to-end business intelligence solution built using Microsoft SQL Server, Python, Jupyter Notebook, and Power BI.

The system transforms historical Brazilian e-commerce data into structured analytical datasets, statistical findings, and interactive business dashboards.

The architecture follows a layered approach:

**Raw CSV Files → SQL Server Staging → Dimensional Data Warehouse → Analytical Views → Python Statistical & ML Analysis → Power BI Reporting**

Each layer separates data ingestion, transformation, analytical modeling, and presentation.

## 2. Technology Stack

| Component | Technology | Purpose |
|---|---|---|
| Source data | Olist CSV datasets | Historical marketplace transactions |
| Development | Python, VS Code, Jupyter | Data ingestion and analysis |
| Data processing | pandas, NumPy | Data profiling and preparation |
| Database | Microsoft SQL Server | Centralized analytical storage |
| Database management | SSMS | SQL development and validation |
| Database connectivity | pyodbc | Python-to-SQL Server integration |
| Statistical analysis | SciPy, statsmodels | Statistical testing and regression |
| Machine learning | scikit-learn | Retrospective classification |
| Visualization | Power BI Desktop | Interactive dashboard development |
| Semantic modeling | Power Query, DAX | Data preparation, relationships, and KPIs |
| Version control | Git, GitHub | Source control and documentation |

## 3. Source Data Layer

The project uses the Brazilian E-Commerce Public Dataset by Olist, covering historical marketplace activity primarily from 2016 through 2018.

Nine CSV files form the source layer:

| Source dataset | Records | Description |
|---|---:|---|
| `olist_customers_dataset.csv` | 99,441 | Customer identifiers and locations |
| `olist_orders_dataset.csv` | 99,441 | Order status and timestamps |
| `olist_order_items_dataset.csv` | 112,650 | Products, sellers, item prices, and freight |
| `olist_order_payments_dataset.csv` | 103,886 | Payment methods, installments, and amounts |
| `olist_order_reviews_dataset.csv` | 99,224 | Customer reviews and scores |
| `olist_products_dataset.csv` | 32,951 | Product attributes and categories |
| `olist_sellers_dataset.csv` | 3,095 | Seller identifiers and locations |
| `olist_geolocation_dataset.csv` | 1,000,163 | Brazilian ZIP-prefix geolocation records |
| `product_category_name_translation.csv` | 71 | Portuguese-to-English product categories |

### Source data considerations

- A single order can contain multiple order items.
- A single order can have multiple payment records.
- An order can have multiple review records.
- `customer_id` identifies the order-associated customer record, whereas `customer_unique_id` supports purchaser-level analysis.
- Geolocation records contain repeated ZIP-prefix observations.
- Some source records have missing values, inconsistent category mappings, or incomplete delivery timestamps.

These conditions influence the warehouse design and analytical rules.

## 4. SQL Server Architecture

**Database:** `OlistEcommerceAnalytics`

**SQL Server instance:** Local development instance

The database contains three primary schemas.

| Schema | Responsibility |
|---|---|
| `stg` | Source-aligned staging tables |
| `dw` | Cleaned warehouse dimensions, facts, and reference data |
| `analytics` | Business-focused reporting views |

### 4.1 Staging Layer — `stg`

The staging layer stores the nine imported datasets while preserving source-level detail.

Its responsibilities include:

- Supporting reproducible ingestion.
- Preserving data needed for auditing.
- Separating raw records from business transformations.
- Providing a baseline for validating warehouse row counts.

Python and pyodbc were used for SQL Server ingestion.

Source values were initially handled conservatively to avoid unintended conversions, with appropriate data types applied during warehouse transformation.

### 4.2 Dimensional Warehouse Layer — `dw`

The warehouse organizes cleaned data into dimensions and fact tables.

**Dimension tables**

| Table | Grain | Purpose |
|---|---|---|
| `dw.dim_customer` | Customer record | Customer identity and location |
| `dw.dim_product` | Product | Product attributes and standardized category |
| `dw.dim_seller` | Seller | Seller identity and location |
| `dw.dim_geography` | ZIP-code prefix | Representative geographic attributes |

**Fact tables**

| Table | Grain | Purpose |
|---|---|---|
| `dw.fact_orders` | One order | Order lifecycle and delivery information |
| `dw.fact_order_items` | One order item | Merchandise and freight charges |
| `dw.fact_payments` | One payment record | Customer payment information |
| `dw.fact_order_reviews` | One review record | Customer satisfaction information |

The warehouse preserves different fact-table grains rather than flattening all records into a single table.

This distinction is necessary because orders, items, payments, and reviews have different one-to-many relationships.

### 4.3 Reference Data

The warehouse includes:

`dw.ref_category_translation_overrides`

This reference table supports additional product-category translations absent from the supplied translation file.

The reporting layer also handles products whose categories remain missing or unmapped.

## 5. Data Cleaning and Business Rules

### Product categories

Product category names are standardized using the supplied translation dataset and supplementary translation overrides.

Products without a usable category mapping are assigned an appropriate unknown/unmapped reporting label.

### Customer identity

The system distinguishes:

- **Order customer records:** Based on `customer_id`.
- **Unique purchasers:** Based on `customer_unique_id`.

This prevents customer counts from being incorrectly interpreted as unique individuals.

### Delivery eligibility

An order is eligible for the delivery performance KPI only when it satisfies the project's delivered-order and valid-delivery-timestamp rules.

Late delivery is determined by comparing actual delivery timing with the promised delivery date.

This avoids treating undelivered or otherwise ineligible orders as on-time deliveries.

### Customer reviews

Where multiple reviews exist for an order, analytical reporting selects the latest answered review using a deterministic ordering rule.

Missing review scores are excluded from reviewed-order satisfaction denominators.

Low satisfaction is defined as a review score of **1 or 2 stars**.

### Payment reconciliation

Expected order charges are calculated from aggregated merchandise values and freight charges.

Recorded payments are independently aggregated at the order level before comparison.

The reconciliation classifies orders into:

- `MATCH`
- `MISSING_ITEMS`
- `DIFFERENCE`
- `MISSING_PAYMENTS`

A tolerance of R$0.01 is used when comparing expected and recorded values.

Reconciliation differences are data-quality or financial-investigation indicators; they are not automatically classified as fraud or realized losses.

## 6. Analytical Reporting Layer — `analytics`

SQL views provide business-ready datasets for dashboard development and statistical analysis.

| View | Reporting grain | Purpose |
|---|---|---|
| `analytics.vw_order_overview` | One order | Executive KPIs, delivery, customer geography, and reconciliation |
| `analytics.vw_category_gmv` | One product category | Overall category merchandise performance |
| `analytics.vw_category_order_items` | One order item | Category GMV with order-level filtering |
| `analytics.vw_payment_method_summary` | One payment method | Payment totals and records by method |
| `analytics.vw_delivery_satisfaction_features` | One eligible reviewed order | Statistical and predictive-analysis feature dataset |

### Avoiding double-counting

Order-item and payment records are aggregated separately before being joined to order-level reporting views.

For example, directly joining multiple order items to multiple payment records on `order_id` can multiply rows and inflate monetary totals.

The architecture avoids that problem by respecting each source's grain.

### Interactive category reporting

`analytics.vw_category_order_items` retains individual order items and their `order_id` values.

In Power BI, this supports a relationship between:

- `Fact_Order_Overview[order_id]` — one side
- `Category_Order_Items[order_id]` — many side

The relationship uses single-direction filtering from the order-level table to the order-item table.

This allows customer-state selections to filter product-category merchandise values.

## 7. Python Analytics Layer

Python accesses prepared analytical data for exploratory, statistical, and machine-learning analysis.

### Statistical analysis

The delivery-satisfaction analysis includes:

- On-time versus late review comparisons.
- Negative-review-rate calculations.
- Chi-square association testing.
- Confidence intervals and effect-size estimation.
- Geographic subgroup analysis.
- Adjusted logistic regression.

The adjusted regression accounts for customer state, purchase period, merchandise value, freight, item and seller counts, and promised delivery duration.

These analyses investigate associations in observational data and do not establish causation.

### Retrospective classification

A regularized logistic classification model was evaluated using chronological training, validation, and test partitions.

The workflow includes:

- Data preparation and feature engineering.
- Chronological model development.
- Validation-based classification-threshold selection.
- Holdout-test evaluation.
- ROC-AUC and average precision.
- Precision, recall, and confusion-matrix analysis.
- Risk concentration analysis within the on-time-delivery subgroup.

**Critical limitation:** The retrospective model uses realized delivery information, including lateness. Therefore, its results must not be presented as evidence of a system capable of predicting dissatisfaction before delivery.

## 8. Power BI Reporting Layer

The project includes four Power BI report pages.

### Executive Overview

Provides high-level operational metrics and marketplace performance.

Main components:

- Total orders.
- Total item GMV.
- Average order value.
- Late delivery rate.
- Recorded customer payments.
- Monthly merchandise value trend.
- Order status distribution.
- Customer-state order volume.
- Top product categories by GMV.

### Revenue & Payments

Investigates the relationship between merchandise charges, recorded payments, and freight.

Main components:

- Payment reconciliation by order.
- Payment value by method.
- Freight share by customer state.

### Fulfillment & Customer Experience

Evaluates delivery reliability and customer review outcomes.

Main components:

- Late delivery rate by customer state.
- Negative review rate by delivery timing.
- Average review score by delivery timing.
- Monthly late delivery rate trend.

### Advanced Insights

Communicates findings from Python statistical analysis and retrospective machine-learning evaluation.

Main components:

- State-level negative-review comparison.
- Adjusted logistic-regression odds ratio.
- ROC-AUC, average precision, precision, and recall.
- Color-coded confusion matrix.
- Highest-risk on-time-order segment comparison.

## 9. Power BI Semantic Model

The report imports analytical SQL Server views rather than connecting directly to raw CSV files.

The principal order-level Power BI table is:

`Fact_Order_Overview`

The interactive product-category table is:

`Category_Order_Items`

Other imported tables contain pre-aggregated payment summaries and static model-evaluation findings.

### Data-model considerations

- Order-level measures use the order-level reporting table.
- Product-category merchandise measures use item-level values.
- Payment method summaries are aggregated independently.
- Statistical and model evaluation summaries are static, disconnected datasets.
- Not every report-level interaction is applicable to every analytical table.
- Report selections are tested to confirm that related visuals filter correctly.

## 10. KPI Definitions

| KPI | Definition |
|---|---|
| Total Orders | Distinct order IDs |
| Unique Purchasers | Distinct `customer_unique_id` values |
| Item GMV | Sum of merchandise item prices, excluding freight |
| Recorded Payments | Sum of recorded customer payment values |
| Average Order Value | Item GMV divided by distinct orders in the selected context |
| Late Delivery Rate | Late deliveries divided by delivery-KPI-eligible orders |
| Freight Share | Freight charges divided by merchandise-plus-freight charges |
| Negative Review Rate | Reviewed orders with 1–2 stars divided by valid reviewed orders |
| Average Review Score | Mean valid customer review score |

**Financial interpretation:** Item GMV is a merchandise-value metric covering recorded order statuses. It is not equivalent to recognized revenue, net revenue, profit, or cash collected.

## 11. Validation and Quality Assurance

Data validation is performed across multiple layers.

### Source and warehouse reconciliation

Previously verified reference totals include:

| Validation metric | Expected total |
|---|---:|
| Orders | 99,441 |
| Order items | 112,650 |
| Payments | 103,886 |
| Products | 32,951 |
| Sellers | 3,095 |
| Item GMV | R$13,591,643.70 |
| Recorded payments | R$16,008,872.12 |
| Delivery-KPI-eligible orders | 96,470 |
| Late deliveries | 6,534 |

### Analytical validation

Checks include:

- Consistency between source and warehouse record counts.
- Unique keys at the expected reporting grain.
- Order-to-item and order-to-payment aggregation consistency.
- Agreement between SQL Server and Power BI headline KPIs.
- Valid review and delivery denominators.
- Consistency between Python model results and static Power BI evaluation tables.
- Correct behavior of report filtering and navigation.

### Visual validation

The Power BI report was tested for:

- Page navigation across all four pages.
- Customer-state filtering of order KPIs.
- Customer-state filtering of product-category GMV.
- Correct clearing of interactive selections.
- Consistent numeric and percentage formatting.
- Appropriate distinctions between static model results and interactive business metrics.

## 12. Reproducibility and Deployment Considerations

The project was developed locally using SQL Server, Python, and Power BI Desktop.

The repository documents the processing and analytical workflow and provides dashboard screenshots.

Power BI report publishing is not required to review the screenshots.

For another developer to reproduce the full workflow, they must configure:

- A local or accessible SQL Server environment.
- The project's source datasets.
- Python dependencies and database connection settings.
- SQL staging, warehouse, and analytical objects.
- Power BI data-source credentials and refresh settings.

The local Python virtual environment (`.venv`) should not be committed to version control.

The original dataset is historical. The project does not provide a real-time data ingestion or live production prediction service.

## 13. Architectural Strengths

The architecture demonstrates several business intelligence engineering practices:

- Separation of staging, warehouse, and reporting layers.
- Explicit definition of analytical data grains.
- Dimensional modeling.
- Prevention of duplicate-counting in SQL joins.
- Reusable reporting views.
- Data-quality and reconciliation checks.
- Consistent business metric definitions.
- Integration of SQL, Python, and Power BI.
- Clear separation of statistical inference and predictive-model evaluation.
- Transparent reporting of limitations.

## 14. Summary

The Olist E-Commerce Analytics architecture transforms nine historical source datasets into a structured SQL Server warehouse, business-ready analytical views, Python-generated statistical and model-evaluation findings, and a four-page interactive Power BI report.

The design emphasizes reproducibility, analytical accuracy, interpretable business metrics, and responsible communication of statistical and machine-learning results.