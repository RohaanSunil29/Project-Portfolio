-- 01_load.sql
-- Turns the raw text tables into clean, typed tables: traffic, items, funnel_ga4.
-- Then runs data quality checks.

-- Helper: "$1,234.50" -> 1234.50 (an empty cell becomes NULL)
CREATE OR REPLACE FUNCTION to_num(t TEXT) RETURNS NUMERIC AS $$
  SELECT NULLIF(REPLACE(REPLACE(TRIM(t), ',', ''), '$', ''), '')::NUMERIC
$$ LANGUAGE SQL IMMUTABLE;

-- 1. Daily traffic --------------------------------------------------------------
DROP TABLE IF EXISTS traffic;
CREATE TABLE traffic AS
SELECT
  -- Looker Studio / Excel write dates in several formats, so check which one each row uses
  CASE
    WHEN "Date" ~ '^\d{8}$'                     THEN TO_DATE("Date", 'YYYYMMDD')    -- 20261025
    WHEN "Date" ~ '^\d{4}-\d{2}-\d{2}$'         THEN "Date"::DATE                   -- 2026-10-25
    WHEN "Date" ~ '^\d{1,2}-[A-Za-z]{3}-\d{2}$' THEN TO_DATE("Date", 'DD-Mon-YY')   -- 25-Oct-26
    ELSE TO_DATE("Date", 'Mon DD, YYYY')                                            -- Oct 25, 2026
  END AS dt,
  "Session default channel group"       AS channel,
  "Device category"                     AS device,
  "New / returning"                     AS user_type,
  to_num("Sessions")::BIGINT            AS sessions,
  to_num("Engaged sessions")::BIGINT    AS engaged_sessions,
  to_num("Add to carts")::BIGINT        AS add_to_carts,
  to_num("Checkouts")::BIGINT           AS checkouts,
  to_num("Ecommerce purchases")::BIGINT AS purchases,
  to_num("Purchase revenue")            AS revenue
FROM raw_daily_traffic;

-- 2. Monthly product data --------------------------------------------------------
DROP TABLE IF EXISTS items;
CREATE TABLE items AS
SELECT
  CASE
    WHEN "Year month" ~ '^\d{6}$'             THEN TO_DATE("Year month" || '01', 'YYYYMMDD')  -- 202610
    WHEN "Year month" ~ '^[A-Za-z]{3}-\d{2}$' THEN TO_DATE("Year month", 'Mon-YY')            -- Oct-26
    ELSE TO_DATE("Year month", 'Mon YYYY')                                                    -- Oct 2026
  END AS month,
  "Item category"                       AS category,
  "Item name"                           AS product,
  to_num("Items viewed")::BIGINT        AS views,
  to_num("Items added to cart")::BIGINT AS added_to_cart,
  to_num("Items purchased")::BIGINT     AS units_sold,
  to_num("Item revenue")                AS revenue
FROM raw_monthly_items;

-- 3. GA4 funnel (copied by hand from a GA4 exploration) -------------------------
DROP TABLE IF EXISTS funnel_ga4;
CREATE TABLE funnel_ga4 AS
SELECT device, step_order::INT AS step_order, step_name, active_users::BIGINT AS active_users
FROM raw_funnel_ga4;

-- 4. Quality checks (run one at a time) ------------------------------------------
-- a) Row counts match the CSVs?
SELECT (SELECT COUNT(*) FROM traffic)    AS traffic_rows,
       (SELECT COUNT(*) FROM items)      AS item_rows,
       (SELECT COUNT(*) FROM funnel_ga4) AS funnel_rows;

-- b) Any dates or months that failed to parse? (both should be 0)
SELECT (SELECT COUNT(*) FROM traffic WHERE dt IS NULL)    AS bad_dates,
       (SELECT COUNT(*) FROM items   WHERE month IS NULL) AS bad_months;

-- c) Date coverage: the demo property starts on 2025-08-20
SELECT MIN(dt), MAX(dt), COUNT(DISTINCT dt) AS days FROM traffic;

-- d) Messy values to exclude later
SELECT channel, COUNT(*) FROM traffic GROUP BY channel ORDER BY 2 DESC;
SELECT COUNT(*) AS unnamed_items FROM items WHERE product IN ('(not set)', '');

-- e) Compare with the GA4 interface: September 2026 by channel
SELECT channel, SUM(sessions) AS sessions, SUM(purchases) AS purchases, ROUND(SUM(revenue), 2) AS revenue
FROM traffic
WHERE dt BETWEEN '2026-09-01' AND '2026-09-30'
GROUP BY channel
ORDER BY sessions DESC;
