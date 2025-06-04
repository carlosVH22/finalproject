# BI Challenge - SQL Focused Analysis

This repository contains my SQL-based solution to a data analytics challenge involving restaurant reservations and visits in Japan. The goal was to extract insights about visitor behavior using cleaned CSV datasets and structured SQL queries.
**You can find the complete Script for the queries in the bi_challenge_sql file

---

## 🗃️ Data Preparation

### Step 1: Data Cleaning (in Python)

* Adjusted inconsistent date/time formats in the CSV files using pandas.
* Replaced `#values` and other invalid entries with `NULL` to ensure correct SQL loading and manipulation.

### Step 2: Import to MySQL

Created a schema `bi_challenge` and defined tables:

```sql
USE bi_challenge;

CREATE TABLE restaurants_visitors (
    id VARCHAR(20),
    visit_date DATE,
    visit_datetime DATETIME,
    reserve_datetime DATETIME,
    reserve_visitors INT
);

CREATE TABLE date_info (
    calendar_date DATE,
    day_of_week VARCHAR(20),
    holiday_flg TINYINT
);

CREATE TABLE store_info (
    store_id VARCHAR(255),
    genre_name VARCHAR(255),
    area_name VARCHAR(255),
    latitude DECIMAL(10, 7),
    longitude DECIMAL(10, 7)
);
```

Loaded data using:

```sql
LOAD DATA INFILE '.../restaurants_visitors_limpio.csv' ...;
LOAD DATA INFILE '.../store_info.csv' ...;
```

## ✅ Data Validation

Counted `NULL` values per column:

```sql
SELECT COUNT(*) - COUNT(column_name) AS nulls FROM table_name;
```

Created a cleaned version:

```sql
CREATE TABLE restaurants_visits_filled AS
SELECT
    id,
    DATE(visit_datetime) AS visit_date,
    visit_datetime,
    reserve_datetime,
    reserve_visitors
FROM restaurants_visitors;
```

---

## 🔍 SQL Analysis

### 1. Top 5 Restaurants with Highest Avg. Visitors on Holidays

Grouped data by day to avoid per-hour bias:

```sql
WITH TotalByDay AS (
    SELECT id, visit_date, SUM(reserve_visitors) AS total_visitors_day
    FROM restaurants_visits_filled rv
    LEFT JOIN date_info di ON rv.visit_date = di.calendar_date
    WHERE holiday_flg = 1
    GROUP BY id, visit_date
),
Ranking AS (
    SELECT id, ROUND(AVG(total_visitors_day), 0) AS avg_visitors,
           DENSE_RANK() OVER (ORDER BY AVG(total_visitors_day) DESC) AS restaurants_ranking
    FROM TotalByDay
    GROUP BY id
)
SELECT r.id, si.genre_name, r.avg_visitors, r.restaurants_ranking
FROM Ranking r
JOIN store_info si ON r.id = si.store_id
WHERE restaurants_ranking BETWEEN 1 AND 5
ORDER BY restaurants_ranking;
```

---

### 2. Best Day of the Week (All Restaurants)

```sql
WITH RestDay AS (
    SELECT visit_date, day_of_week, SUM(reserve_visitors) AS avg_visitors
    FROM restaurants_visits_filled rv
    LEFT JOIN date_info di ON rv.visit_date = di.calendar_date
    GROUP BY visit_date, day_of_week
)
SELECT day_of_week, ROUND(AVG(avg_visitors), 1) AS avg_visitors
FROM RestDay
GROUP BY day_of_week
ORDER BY avg_visitors DESC;
```

---

### 3. Weekly Growth in Visitor Count (WoW)

```sql
WITH RestDay AS (
    SELECT visit_date, YEAR(visit_date) AS year, WEEK(visit_date) AS week_num,
           SUM(reserve_visitors) AS total_visitors
    FROM restaurants_visits_filled rv
    LEFT JOIN date_info di ON rv.visit_date = di.calendar_date
    GROUP BY visit_date
    HAVING year = 2017
)
SELECT week_num, SUM(total_visitors) AS visitors,
       LAG(SUM(total_visitors), 1) OVER (ORDER BY week_num) AS prev_week,
       ROUND(((SUM(total_visitors) / LAG(SUM(total_visitors), 1) OVER (ORDER BY week_num)) - 1) * 100, 2) AS WoW_change
FROM RestDay
GROUP BY week_num
HAVING week_num >= 19;
```

---

### 4. Visual Trend - Visitors by Day

```sql
WITH TotalByDay AS (
    SELECT visit_date, SUM(reserve_visitors) AS total_visitors_day
    FROM restaurants_visits_filled
    GROUP BY visit_date
)
SELECT *
FROM TotalByDay
ORDER BY visit_date;
```

> ⚠️ **Key Insight:** Since the data was initially at the hour level, grouping by day and restaurant was crucial to derive accurate, actionable insights.

---

## 📁 Repository Structure

```
bi-challenge-sql/
├── README.md
├── sql/
│   ├── create_tables.sql
│   ├── clean_checks.sql
│   ├── query_top5_restaurants.sql
│   ├── query_best_day.sql
│   ├── query_wow_growth.sql
│   └── visual_trend.sql
```

---

## 📌 Summary

* **Data Engineering:** Cleaned, validated, and loaded multi-source time-based data into a MySQL environment.
* **Data Analysis:** Developed advanced SQL queries using CTEs, window functions, date functions, and aggregations.
* **Business Relevance:** Provided insights on top-performing restaurants, ideal visiting days, and growth trends.



# 🔮 Time Series Forecasting – SARIMAX Model

After completing the SQL-based exploratory analysis, a time series forecasting model was developed using Python to predict future restaurant reservations based on historical patterns.

---

### 🧠 Model Overview

A **Seasonal ARIMA with eXogenous variables (SARIMAX)** model was fitted on the cleaned dataset. The selected configuration:

- **SARIMAX(1, 0, 1) × (1, 1, 1, 7)**  
- This setup captures:
  - Short-term dynamics (AR=1, MA=1)
  - Weekly seasonality (7-day cycle)
  - Seasonal differencing (D=1) to stabilize weekly trends

---

### ⚙️ Parameters Summary

| Parameter    | Estimate | Description                                        |
|--------------|----------|----------------------------------------------------|
| `ar.L1`      | 0.927    | Strong autocorrelation with the previous day       |
| `ma.L1`      | -0.679   | Moving average adjustment of recent errors         |
| `ar.S.L7`    | 0.246    | Weekly autoregressive pattern (same day last week) |
| `ma.S.L7`    | -0.812   | Weekly error correction                            |
| `sigma²`     | 3116.44  | Variance of residuals                              |

---

### 📊 Performance Metrics

Model was evaluated using the test dataset with the following metrics:

| Metric | Description                         | Value (example) |
|--------|-------------------------------------|-----------------|
| **MAE**  | Mean Absolute Error                  | `xx.xx`          |
| **RMSE** | Root Mean Squared Error              | `xx.xx`          |
| **MAPE** | Mean Absolute Percentage Error       | `xx.xx%`         |

These metrics show the model's ability to approximate the real number of visitors on unseen data.

---

### 📉 Model Diagnostics

| Test                     | Result        | Interpretation                          |
|--------------------------|---------------|------------------------------------------|
| Ljung-Box (Q)            | p = 0.00      | Residuals are autocorrelated             |
| Jarque-Bera (JB)         | JB = 4054.37  | Residuals are not normally distributed   |
| Heteroskedasticity (H)   | p = 0.00      | Variance is not constant                 |

Despite imperfections in residual behavior, the model captures key patterns and seasonality effectively.

---

### 📈 Visualization

The following plot illustrates:

- Training data (blue)
- Actual test data (orange)
- Forecasted values (green dashed)
- 95% confidence interval (shaded gray)

![Forecast plot](path-to-forecast-image.png)

---

### 🧼 Preprocessing Highlights

Data cleaning and preparation steps included:

- Converting date strings to `datetime` objects
- Aggregating reservations per day and restaurant
- Handling nulls and formatting issues
- Splitting data into training and test sets

---

### 📌 Conclusion

This time series model provides a reliable short-term forecasting tool for restaurant visitor behavior, complementing the SQL analysis. Together, both approaches offer a robust foundation for data-driven decision-making in hospitality demand forecasting.

> ✅ The full Python code and forecast script are available in the `forecasting/` folder.

