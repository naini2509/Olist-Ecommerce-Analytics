# Olist E-Commerce Intelligence
## Business Insights & Strategic Recommendations

**Analysis Period:** Historical Olist transactions, 2016–2018
**Tools:** SQL Server | Python | Statistical Analysis | Machine Learning | Power BI
**Report Type:** Business Intelligence & Operational Performance Analysis

---

## 1. Executive Summary

This project analyzed historical Brazilian e-commerce transactions to evaluate merchandise performance, customer payment behavior, fulfillment reliability, and customer satisfaction.

The analysis combined nine source datasets into a SQL Server data warehouse, supported by statistical analysis in Python and a four-page Power BI dashboard.

### Key Performance Indicators

| Metric | Result |
|---|---:|
| Total Orders | 99,441 |
| Unique Purchasers | 96,096 |
| Merchandise GMV | R$13,591,643.70 |
| Recorded Payments | R$16,008,872.12 |
| Average Order Value | R$137.75 |
| Late Delivery Rate | 6.77% |

**Central finding:** Delivery reliability is strongly associated with customer satisfaction. Orders delivered late received negative reviews substantially more frequently than orders delivered on time.

Payment reconciliation also identified a smaller group of transactions requiring investigation.

These findings support recommendations around delivery monitoring, customer experience, and payment-data quality.

---

## 2. Merchandise Performance

### Findings

The historical dataset contains 99,441 orders and 112,650 order-item records.

Recorded merchandise value totals **R$13.59 million**, excluding freight.

The largest product categories by merchandise value include:

- Health and Beauty
- Watches and Gifts
- Bed, Bath and Table

Customer demand is concentrated in major Brazilian states, particularly São Paulo, Rio de Janeiro, and Minas Gerais.

### Business Implications

Product-category performance can help inform assortment analysis and commercial planning.

Geographic order concentration may also influence decisions related to inventory positioning and logistics capacity.

### Recommendations

- Monitor merchandise value and order volume by product category.
- Compare regional demand patterns over time.
- Evaluate category performance alongside order volume, rather than GMV alone.
- Investigate whether high-demand regions present opportunities for improved fulfillment efficiency.

**Metric limitation:** GMV includes recorded order items across all order statuses. It is not equivalent to recognized revenue or profit.

---

## 3. Payment Intelligence & Reconciliation

### Payment Method Performance

| Payment Method | Recorded Payment Value |
|---|---:|
| Credit Card | R$12,542,084.19 |
| Boleto | R$2,869,361.27 |
| Voucher | R$379,436.87 |
| Debit Card | R$217,989.79 |
| Not Defined | R$0.00 |

Credit cards account for approximately **78.35% of recorded payment value**.

This demonstrates the importance of card-payment operations within the historical dataset.

### Order-Level Reconciliation

Recorded payments were compared against merchandise-plus-freight charges at the individual order level.

| Reconciliation Status | Orders |
|---|---:|
| MATCH | 98,362 |
| MISSING_ITEMS | 775 |
| DIFFERENCE | 303 |
| MISSING_PAYMENTS | 1 |
| **Total** | **99,441** |

Approximately **98.91% of orders matched** within the defined tolerance of R$0.01.

### Business Implications

Most orders reconcile successfully, but unmatched transactions indicate potential data completeness, processing, or reconciliation issues.

These exceptions warrant investigation before drawing conclusions about financial loss.

### Recommendations

- Implement recurring order-level reconciliation checks.
- Investigate missing item records and missing payment records separately.
- Monitor reconciliation exceptions by order status.
- Define clear ownership and resolution procedures for unresolved differences.

A payment discrepancy should not automatically be classified as fraud or revenue leakage.

---

## 4. Fulfillment Performance

### Delivery Reliability

The dataset contains:

- **96,470** delivery-KPI-eligible orders
- **6,534** late deliveries
- **6.77%** overall late delivery rate

Delivery performance varies by customer state and purchase period.

### Freight Analysis

Recorded freight charges total **R$2,251,909.54**.

Freight represents approximately **14.21%** of total merchandise-plus-freight charges.

Regional differences in freight share may reflect shipping distance, product characteristics, order composition, and other factors.

### Business Implications

Delivery delays can create risks for customer satisfaction.

Freight affordability also deserves monitoring, particularly in regions where shipping charges represent a larger proportion of customer spending.

### Recommendations

- Develop regional delivery-reliability scorecards.
- Investigate periods with elevated late delivery rates.
- Monitor freight share alongside order volume and average order value.
- Evaluate the feasibility of logistics improvements in high-demand regions.

Freight share reflects recorded customer charges, not the seller's actual shipping expenditure.

---

## 5. Customer Experience & Satisfaction

### Review Outcomes by Delivery Timing

| Metric | On-Time Delivery | Late Delivery |
|---|---:|---:|
| Reviewed Orders | 89,443 | 6,381 |
| Average Review Score | 4.29 / 5 | 2.27 / 5 |
| Negative Review Rate | 9.27% | 62.42% |

Negative reviews were approximately **6.74 times as common** among late deliveries as among on-time deliveries.

The absolute difference in negative-review rates was approximately **53.15 percentage points**.

### Statistical Evidence

A chi-square test found a statistically significant association between delivery timing and negative ratings.

**Chi-square statistic:** 15,068.91
**p-value:** Less than 0.001

An adjusted logistic regression estimated:

**Adjusted Odds Ratio:** 17.23
**95% Confidence Interval:** 16.24–18.28
**p-value:** Less than 0.001

The adjusted analysis accounted for customer geography, purchase month, and selected order-level characteristics.

### Business Implications

Delivery reliability appears to be an important indicator associated with customer satisfaction.

The relationship remained strong after adjustment for the measured characteristics.

However, the study is observational and does not demonstrate that lateness caused every negative rating.

### Recommendations

- Treat late delivery as a key customer-experience monitoring signal.
- Evaluate proactive communication for delayed orders.
- Test service-recovery approaches for affected customers.
- Measure whether proposed interventions improve satisfaction through controlled evaluation.

---

## 6. Advanced Analytics & Machine Learning

A retrospective logistic classification model evaluated whether historical order characteristics could distinguish low-rated orders.

### Holdout-Test Performance

| Metric | Result |
|---|---:|
| ROC-AUC | 0.6633 |
| Average Precision | 0.2660 |
| Precision | 28.55% |
| Recall | 37.06% |
| Test Orders | 19,165 |

The classification threshold of **0.1174** was selected using validation data.

### Confusion Matrix

| Actual Outcome | Predicted Not Low | Predicted Low |
|---|---:|---:|
| Not Low | 15,592 | 1,719 |
| Low Rating | 1,167 | 687 |

### High-Risk Segment Analysis

Among on-time test orders:

- Overall negative-review rate: **8.35%**
- Highest-risk 10% negative-review rate: **21.12%**
- Risk concentration lift: approximately **2.53×**

### Interpretation

The model demonstrated moderate retrospective ranking performance.

The highest-risk segment contained a higher concentration of negative reviews than the overall on-time subgroup.

However, the model also produced false positives and missed low-rated orders.

**Critical limitation:** The model uses realized delivery information. It is not a validated pre-delivery prediction system and should not be deployed as one without additional development and testing.

---

## 7. Prioritized Business Recommendations

| Priority | Recommendation | Suggested Monitoring Metric |
|---|---|---|
| High | Improve late-delivery monitoring | Late Delivery Rate |
| High | Investigate payment reconciliation exceptions | Unmatched Orders |
| High | Evaluate customer recovery after delayed deliveries | Negative Review Rate |
| Medium | Review regional freight affordability | Freight Share |
| Medium | Monitor product-category performance | Category GMV |
| Future | Develop a genuinely pre-delivery risk model | Prospective ROC-AUC, Precision, Recall |

These recommendations describe potential business actions, not interventions whose financial or operational impact has already been demonstrated.

---

## 8. Project Limitations

The analysis has several important limitations:

1. **Historical data:** The dataset represents transactions from 2016–2018 and does not reflect current marketplace performance.
2. **Incomplete coverage:** Some early months contain sparse records, while the final months contain incomplete transaction coverage.
3. **Observational relationships:** Statistical associations cannot automatically be interpreted as causal effects.
4. **Payment interpretation:** Recorded payments and item GMV do not directly represent recognized revenue or profit.
5. **Sample sizes:** Regional satisfaction percentages may be unstable for states with few reviewed deliveries.
6. **Retrospective modeling:** The machine-learning model uses information that would not be available before delivery.
7. **Static analytical results:** Model performance summaries in Power BI do not dynamically recalculate with report filters.

These limitations should be considered when applying the findings to business decisions.

---

## 9. Conclusion

The Olist E-Commerce Intelligence project demonstrates how a structured data warehouse, statistical analysis, and business intelligence dashboards can support operational decision-making.

The analysis identified three major areas for attention:

- **Delivery reliability:** Late deliveries were strongly associated with lower customer satisfaction.
- **Payment data quality:** Most transactions reconciled, but exceptions require further investigation.
- **Regional performance:** Customer demand and freight characteristics varied geographically.

The project also demonstrated the importance of separating descriptive analytics, statistical inference, and retrospective machine-learning evaluation.

The final recommendations emphasize reliable metrics, transparent interpretation, and business decisions supported by measurable evidence.