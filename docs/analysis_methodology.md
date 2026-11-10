# Olist E-Commerce Analytics — Statistical & Machine Learning Methodology

## 1. Overview

This document describes the statistical and machine-learning methodology used to analyze the relationship between delivery performance and customer dissatisfaction in the Olist Brazilian E-Commerce dataset.

The analysis combines SQL Server data preparation, Python statistical testing, logistic regression, chronological model evaluation, and Power BI visualization.

**Primary research question:**

> How strongly is late delivery associated with negative customer reviews, and how effectively can historical order characteristics distinguish dissatisfied customers?

The project includes two separate analytical objectives:

1. **Statistical inference:** Quantify and evaluate the association between late deliveries and negative customer ratings.
2. **Retrospective classification:** Evaluate whether historical order and delivery characteristics can distinguish orders receiving low ratings.

The findings are observational and do not establish causal relationships.

---

## 2. Analytical Data Source

**Source dataset:** Brazilian E-Commerce Public Dataset by Olist

**Database:** `OlistEcommerceAnalytics`

**Primary analytical view:** `analytics.vw_delivery_satisfaction_features`

**Statistical analysis sample:** 95,824 eligible reviewed orders.

The analytical view combines order, customer, delivery, merchandise, and review information while retaining one record per eligible reviewed order.

### Data preparation

Before statistical analysis:

- Standardized order and delivery timestamps.
- Applied delivery eligibility rules.
- Distinguished on-time from late deliveries.
- Selected one review per order using a deterministic latest-answered-review rule.
- Excluded orders without valid review outcomes from satisfaction-rate denominators.
- Aggregated order-item and payment information before joining to order-level datasets.
- Prepared geographic, temporal, and order-level explanatory variables.

This prevented duplicate observations caused by one-to-many relationships between orders, items, payments, and reviews.

## 3. Variable Definitions

### 3.1 Outcome Variable — Customer Dissatisfaction

Customer dissatisfaction was defined using review scores.

| Review score | Classification |
|---|---|
| 1–2 stars | Low rating (1) |
| 3–5 stars | Not low rating (0) |
| Missing review | Excluded from reviewed-order analysis |

The binary outcome variable is `low_rating_flag`.

### 3.2 Primary Explanatory Variable — Late Delivery

An order was classified as late when its actual delivery date exceeded its promised delivery date, subject to the project's delivery eligibility rules.

| Delivery timing | Classification |
|---|---|
| Delivered on or before promised date | On Time |
| Delivered after promised date | Late |
| Ineligible for delivery KPI | Excluded |

### 3.3 Additional Explanatory Variables

The adjusted analysis considered:

- Customer state.
- Purchase month.
- Merchandise value.
- Freight charges.
- Order item count.
- Distinct seller count.
- Promised delivery duration.

These variables provide additional context when estimating the association between delivery lateness and customer ratings.

They should not be interpreted as an exhaustive set of factors influencing customer satisfaction.

---

## 4. Descriptive Statistical Analysis

The initial analysis compared customer review outcomes between on-time and late deliveries.

### Validated results

| Metric | On Time | Late |
|---|---:|---:|
| Reviewed orders | 89,443 | 6,381 |
| Negative reviews | 8,289 | 3,983 |
| Negative review rate | 9.27% | 62.42% |
| Average review score | 4.29 | 2.27 |

The two groups contain a combined **95,824 reviewed orders**.

### Negative review rate

The group-specific negative review rate was calculated as:

\[
\text{Negative Review Rate} =
\frac{\text{Low-Rated Orders}}{\text{Reviewed Orders}}
\times 100
\]

### Absolute difference

The negative-review-rate difference between late and on-time deliveries was approximately:

**53.15 percentage points**

The estimated 95% confidence interval for this difference was:

**51.95 to 54.36 percentage points**

### Relative risk

The ratio of the two negative-review rates was approximately:

**6.74**

This means negative reviews were approximately 6.74 times as common among late deliveries as among on-time deliveries within the analyzed sample.

This descriptive risk ratio is different from the odds ratio obtained from logistic regression.

---

## 5. Chi-Square Association Test

A chi-square test of independence was used to assess whether delivery timing and negative-review classification were statistically associated.

### Hypotheses

**Null hypothesis (H₀):**

Delivery timing and low-rating classification are statistically independent.

**Alternative hypothesis (H₁):**

Delivery timing and low-rating classification are associated.

### Results

| Statistic | Result |
|---|---:|
| Chi-square statistic | 15,068.91 |
| p-value | Less than 0.001 |

The analysis provided strong evidence against independence between delivery timing and low customer ratings.

### Interpretation

Late delivery and customer dissatisfaction exhibited a statistically significant association.

Statistical significance does not establish causation, and the magnitude of the chi-square statistic should not be interpreted as a direct measure of operational impact.

---

## 6. Geographic Subgroup Analysis

The delivery-satisfaction relationship was examined across Brazilian customer states to determine whether the overall finding was driven primarily by a small number of regions.

### Minimum sample-size criteria

For the regional comparison, states were included when they had at least:

- **100 reviewed on-time deliveries**
- **30 reviewed late deliveries**

A total of **21 states** satisfied these criteria.

### Finding

All 21 qualifying states showed a higher negative-review rate for late deliveries than for on-time deliveries.

This suggests that the relationship was geographically widespread within the available historical data.

### Limitations

The minimum sample-size thresholds are practical reporting criteria, not guarantees of statistical precision.

Smaller states may still have wider uncertainty intervals.

State-level comparisons can also reflect differences in shipping networks, customer expectations, product types, seller characteristics, and other unobserved factors.

---

## 7. Adjusted Logistic Regression

A logistic regression model was used to estimate the relationship between late delivery and the probability of receiving a low rating while accounting for measured order-level characteristics.

### Model outcome

Binary customer dissatisfaction:

- 1 = low review score (1–2 stars)
- 0 = other valid review score (3–5 stars)

### Adjustment variables

The model controlled for:

- Customer state.
- Purchase month.
- Item merchandise value.
- Freight charges.
- Item count.
- Seller count.
- Promised delivery duration.

The analysis was implemented in Python using `statsmodels`.

### Regression results

| Metric | Result |
|---|---:|
| Observations | 95,824 |
| Adjusted odds ratio for late delivery | 17.23 |
| 95% confidence interval | 16.24–18.28 |
| p-value | Less than 0.001 |

### Interpretation

After adjustment for the included variables, late deliveries were associated with approximately **17.23 times the odds** of receiving a low customer rating compared with on-time deliveries.

**This is an odds ratio, not a risk ratio or probability multiplier.**

It must not be described as a 17.23-fold increase in the probability of dissatisfaction.

### Standardized model-based comparison

The adjusted model also produced approximate standardized low-rating probabilities:

| Delivery scenario | Model-based probability |
|---|---:|
| On Time | 9.27% |
| Late | 61.25% |

The difference was approximately **51.97 percentage points**.

These are model-based estimates under specified statistical assumptions, not observed effects from a randomized intervention.

### Statistical limitations

- The data is observational.
- Not all potentially relevant confounding factors are available.
- Logistic regression associations are sensitive to model specification.
- Statistical significance does not demonstrate causality.
- Results describe historical Olist transactions rather than current marketplace operations.

---

## 8. Retrospective Machine Learning

A regularized logistic classification model was evaluated to investigate how effectively historical order characteristics distinguish low-rated orders.

This classification task is separate from the statistical inference analysis.

### Model objective

Predict the historical binary review outcome:

- Low rating.
- Not low rating.

### Model features

The retrospective modeling workflow used order and delivery characteristics from the analytical dataset, including realized delivery information.

**Important:** Because actual delivery lateness is available only after delivery, this model is not a validated system for predicting dissatisfaction before an order is delivered.

---

## 9. Chronological Data Splitting

The dataset was divided chronologically instead of using a random train-test split.

### Partitioning strategy

| Partition | Approximate share |
|---|---:|
| Training | 64% |
| Validation | 16% |
| Test | 20% |

The earlier historical orders were used for model development, while later orders were reserved for evaluation.

### Why chronological splitting?

Chronological partitioning better reflects how historical observations might be used to evaluate performance on later transactions.

It also helps identify changes in outcome rates and operational conditions across periods.

However, chronological splitting alone does not eliminate every possible source of information leakage.

---

## 10. Model Evaluation Metrics

The classification model was assessed using multiple metrics.

### ROC-AUC

Measures the model's ability to rank positive cases above negative cases across classification thresholds.

**Test ROC-AUC: 0.6633**

### Average Precision (AP)

Summarizes precision across recall levels and is useful when the positive outcome is relatively uncommon.

**Test Average Precision: 0.2660**

### Precision

Among orders predicted to have low ratings, the proportion actually receiving low ratings.

**Test precision: 28.55%**

### Recall

Among orders that actually received low ratings, the proportion correctly identified.

**Test recall: 37.06%**

### F1 Score

The harmonic mean of precision and recall.

**Test F1 score: approximately 0.3225**

The results indicate moderate retrospective classification performance, with substantial false-positive and false-negative errors.

---

## 11. Classification Threshold Selection

The model's predicted probabilities were converted into binary classifications using a threshold selected on the validation dataset.

### Selected threshold

**0.1174**

The threshold was chosen using a validation-set criterion targeting at least 50% recall.

### Why not use 0.50 automatically?

A classification threshold of 0.50 is not necessarily optimal for imbalanced outcomes or business objectives where false positives and missed cases carry different costs.

Threshold selection should be conducted on validation data, not optimized repeatedly on the test set.

### Test-set performance

At the validation-selected threshold:

| Metric | Result |
|---|---:|
| Precision | 28.55% |
| Recall | 37.06% |
| F1 score | 0.3225 |

The test recall was lower than the validation target, demonstrating that threshold behavior did not transfer perfectly to the later test period.

---

## 12. Confusion Matrix

The chronological test set contained **19,165 orders**.

| Actual outcome | Predicted Not Low | Predicted Low |
|---|---:|---:|
| Not Low | 15,592 | 1,719 |
| Low Rating | 1,167 | 687 |

### Interpretation

**True negatives — 15,592**

Orders correctly classified as not receiving low ratings.

**False positives — 1,719**

Orders flagged as low-rating cases that did not receive a low rating.

**False negatives — 1,167**

Low-rated orders that the model failed to identify.

**True positives — 687**

Low-rated orders correctly identified.

### Operational implications

The number of false positives and false negatives illustrates why model performance must be evaluated against a clearly defined operational use case.

A model that identifies some high-risk observations may still be unsuitable for automated customer interventions.

---

## 13. Test-Period Distribution Changes

The historical validation and test periods had different outcome distributions.

The low-rating and late-delivery rates declined between the validation and test periods.

This shift matters because:

- Classification precision depends partly on outcome prevalence.
- A threshold chosen in one period may perform differently later.
- Historical performance may not remain stable under changing conditions.

Future deployment-oriented work would require monitoring model calibration, ranking performance, and changes in data distributions.

---

## 14. On-Time Delivery Subgroup Analysis

A separate analysis evaluated retrospective risk ranking among orders that were delivered on time.

This subgroup analysis is useful because actual late delivery is an especially strong signal in the complete historical dataset.

### On-time test group

| Metric | Value |
|---|---:|
| On-time test orders | 18,508 |
| Low-rated on-time orders | 1,546 |
| Baseline negative-review rate | 8.35% |
| On-time subgroup ROC-AUC | 0.6100 |
| On-time subgroup Average Precision | 0.1719 |

### Highest-risk 10%

The highest-ranked 10% of on-time orders contained:

**1,851 orders**

Their negative-review rate was:

**21.12%**

Compared with the 8.35% subgroup baseline, this represented approximately:

**2.53× lift**

### Interpretation

The retrospective model concentrated a greater share of low-rated on-time orders within its highest-risk group.

The high-risk group is a subset of all on-time orders, not an independent comparison population.

This result is exploratory and should not be described as proven pre-delivery prediction performance.

---

## 15. Power BI Presentation of Analytical Results

The **Advanced Insights** page displays several statistical and machine-learning findings.

### Regional comparison

A clustered bar chart compares negative-review rates for late and on-time deliveries by state.

Only states meeting the specified sample-size criteria are shown.

### Adjusted odds ratio

A statistical insight card displays:

**17.23× adjusted odds ratio**

**95% CI: 16.24–18.28**

The card identifies the result as observational rather than causal.

### Model evaluation metrics

Four indicators summarize the chronological test-set model:

- ROC-AUC.
- Average Precision.
- Precision.
- Recall.

### Confusion matrix

A static Power BI matrix displays the four verified classification outcomes.

Green indicates correct classifications and orange indicates errors.

### Highest-risk segment comparison

A two-bar chart compares the baseline negative-review rate against the highest-risk 10% of on-time test orders.

These statistical and model evaluation results are imported as static summaries and do not dynamically recalculate with ordinary report filters.

---

## 16. Limitations and Responsible Interpretation

### Observational analysis

The historical dataset was not generated by a randomized experiment.

Therefore, associations between delivery timing and customer satisfaction cannot automatically be interpreted as causal effects.

### Historical coverage

The data primarily covers 2016–2018.

Some early months have sparse records, and the final months have incomplete transaction coverage.

Monthly trend charts use appropriate reporting windows to avoid misleading interpretations.

### Missing and duplicate records

Some source datasets contain missing timestamps, missing categories, missing reviews, and multiple reviews for the same order.

The analysis applies documented cleaning and selection rules.

### Data leakage and feature timing

The retrospective classifier uses realized delivery information.

A true pre-delivery prediction system would require a newly defined feature set containing only information available at the prediction time.

It would also require a separate deployment-oriented evaluation.

### Model limitations

The model's holdout performance is moderate.

Its false-positive and false-negative rates mean it should not be presented as a ready-to-deploy automated intervention system.

### Generalizability

Results from historical Olist transactions may not generalize to other marketplaces, shipping networks, customer populations, or current business conditions.

---

## 17. Business Recommendations

The analysis supports several potential business actions.

### Monitor delivery reliability

Track delivery punctuality by region and period to identify operational areas requiring investigation.

### Evaluate customer recovery workflows

Consider testing service-recovery processes for customers whose deliveries are delayed.

The effectiveness of such interventions would need to be evaluated rather than assumed.

### Investigate regional variation

Compare satisfaction and delivery performance across states while accounting for differences in sample size.

### Strengthen financial and operational data quality

Maintain consistent order-level definitions and investigate missing records or reconciliation differences.

### Validate models before operational use

If operational prediction is considered, develop a separate model using only features available at the intended decision point.

Evaluate that model prospectively with suitable performance, calibration, fairness, and monitoring checks.

---

## 18. Reproducibility

The statistical and model-evaluation workflow was developed using Python and SQL Server.

Key technologies include:

- pandas and NumPy for data preparation.
- SciPy for statistical testing.
- statsmodels for adjusted logistic regression.
- scikit-learn for retrospective classification and evaluation.
- SQL Server analytical views for prepared source data.
- Power BI for visualizing validated results.

The project's SQL scripts, Python notebooks, and accompanying documentation provide the basis for reproducing the analysis in a suitably configured environment.

## 19. Conclusion

The project identified a strong statistical association between delivery lateness and negative customer reviews.

Late deliveries had substantially higher negative-review rates and lower average review scores than on-time deliveries, and the relationship remained pronounced after adjustment for measured characteristics.

The retrospective classification exercise demonstrated moderate ability to distinguish dissatisfied orders and concentrate negative reviews within higher-ranked groups.

Together, these analyses illustrate how SQL Server, Python, statistical inference, machine learning, and Power BI can be combined to support evidence-based e-commerce business intelligence.

The project deliberately distinguishes descriptive findings, adjusted statistical associations, retrospective model performance, and claims that would require causal or prospective validation.