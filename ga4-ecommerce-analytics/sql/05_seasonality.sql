-- 05_seasonality.sql
-- Did the 2025 holiday season lift buying, and how is the store trending?
-- The demo property only holds data from 20 Aug 2025, so there is no 2024 holiday to compare with:
-- holiday periods are compared with normal days (per-day averages), and year-over-year only
-- covers September and 1-25 October, the days present in both years.

-- 1. Monthly trend (Aug 2025 and Oct 2026 are partial months)
DROP TABLE IF EXISTS monthly;
CREATE TABLE monthly AS
SELECT
  DATE_TRUNC('month', dt)::DATE AS month,
  COUNT(DISTINCT dt)            AS days,
  SUM(sessions)                 AS sessions,
  SUM(purchases)                AS purchases,
  ROUND(SUM(revenue), 2)        AS revenue,
  ROUND(100.0 * SUM(purchases) / NULLIF(SUM(sessions), 0), 2) AS conversion_rate_pct
FROM traffic
GROUP BY 1;

SELECT * FROM monthly ORDER BY month;

-- 2. Holiday 2025 vs normal days.
--    Periods differ in length (4 days vs 304), so compare per-day averages, not totals.
WITH daily AS (
  SELECT dt, SUM(sessions) AS sessions, SUM(purchases) AS purchases, SUM(revenue) AS revenue
  FROM traffic
  WHERE dt BETWEEN '2025-10-01' AND '2026-09-30'
  GROUP BY dt
),
periods AS (
  SELECT
    CASE
      WHEN dt BETWEEN '2025-11-01' AND '2025-11-27' THEN '1. Pre-Black Friday (1-27 Nov)'
      WHEN dt BETWEEN '2025-11-28' AND '2025-12-01' THEN '2. Black Friday to Cyber Monday'
      WHEN dt BETWEEN '2025-12-02' AND '2025-12-24' THEN '3. December run-up (2-24 Dec)'
      WHEN dt BETWEEN '2025-12-25' AND '2025-12-31' THEN '4. Christmas to New Year'
      ELSE '0. Normal days'
    END AS period,
    COUNT(*)                                                    AS days,
    SUM(sessions) / COUNT(*)                                    AS sessions_per_day,
    SUM(revenue) / COUNT(*)                                     AS revenue_per_day,
    100.0 * SUM(purchases) / NULLIF(SUM(sessions), 0)           AS conversion_rate_pct,
    SUM(revenue) / NULLIF(SUM(purchases), 0)                    AS avg_order_value
  FROM daily
  GROUP BY 1
)
-- FIRST_VALUE(...) is the "0. Normal days" row, so each *_vs_normal_pct compares with a normal day
SELECT period, days,
  ROUND(sessions_per_day)         AS sessions_per_day,
  ROUND(revenue_per_day)          AS revenue_per_day,
  ROUND(conversion_rate_pct, 2)   AS conversion_rate_pct,
  ROUND(avg_order_value, 2)       AS avg_order_value,
  ROUND(100.0 * (sessions_per_day    / FIRST_VALUE(sessions_per_day)    OVER (ORDER BY period) - 1), 1) AS sessions_vs_normal_pct,
  ROUND(100.0 * (conversion_rate_pct / FIRST_VALUE(conversion_rate_pct) OVER (ORDER BY period) - 1), 1) AS conversion_vs_normal_pct,
  ROUND(100.0 * (revenue_per_day     / FIRST_VALUE(revenue_per_day)     OVER (ORDER BY period) - 1), 1) AS revenue_vs_normal_pct
FROM periods
ORDER BY period;

-- 3. Year-over-year, same calendar days (1 Sep - 25 Oct)
WITH by_month AS (
  SELECT EXTRACT(YEAR FROM dt)::INT AS yr, EXTRACT(MONTH FROM dt)::INT AS mon,
    SUM(sessions) AS sessions, SUM(purchases) AS purchases, SUM(revenue) AS revenue
  FROM traffic
  WHERE dt BETWEEN '2025-09-01' AND '2025-10-25'
     OR dt BETWEEN '2026-09-01' AND '2026-10-25'
  GROUP BY 1, 2
)
SELECT yr, mon, sessions, purchases, ROUND(revenue, 2) AS revenue,
  ROUND(100.0 * purchases / NULLIF(sessions, 0), 2) AS conversion_rate_pct,
  -- LAG with PARTITION BY month = the same month one year earlier
  ROUND(100.0 * (sessions::NUMERIC / NULLIF(LAG(sessions) OVER (PARTITION BY mon ORDER BY yr), 0) - 1), 1) AS sessions_yoy_pct,
  ROUND(100.0 * (revenue           / NULLIF(LAG(revenue)  OVER (PARTITION BY mon ORDER BY yr), 0) - 1), 1) AS revenue_yoy_pct
FROM by_month
ORDER BY mon, yr;

-- 4. Returning visitors' share of revenue, by month
SELECT DATE_TRUNC('month', dt)::DATE AS month,
  ROUND(100.0 * SUM(revenue) FILTER (WHERE user_type = 'returning') / NULLIF(SUM(revenue), 0), 1) AS returning_revenue_pct
FROM traffic
GROUP BY 1
ORDER BY 1;
