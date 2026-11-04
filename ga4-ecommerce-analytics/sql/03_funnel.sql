-- 03_funnel.sql
-- Where are buyers lost? Two views of the funnel, 1 Oct 2025 - 30 Sep 2026.

-- A. Event funnel from the traffic table (counts actions, so one user can count several times)
DROP TABLE IF EXISTS funnel;
CREATE TABLE funnel AS
WITH totals AS (
  SELECT device,
    SUM(sessions)     AS sessions,
    SUM(add_to_carts) AS add_to_carts,
    SUM(checkouts)    AS checkouts,
    SUM(purchases)    AS purchases
  FROM traffic
  WHERE dt BETWEEN '2025-10-01' AND '2026-09-30'
  GROUP BY device
)
-- one row per step (the shape Power BI's funnel chart needs)
SELECT device, 1 AS step_order, 'Sessions'    AS step_name, sessions     AS volume FROM totals
UNION ALL SELECT device, 2, 'Add to cart', add_to_carts FROM totals
UNION ALL SELECT device, 3, 'Checkout',    checkouts    FROM totals
UNION ALL SELECT device, 4, 'Purchase',    purchases    FROM totals;

-- % of the previous step reached (LAG = value of the previous row)
SELECT device, step_name, volume,
  ROUND(100.0 * volume / NULLIF(LAG(volume) OVER (PARTITION BY device ORDER BY step_order), 0), 1) AS pct_of_previous_step
FROM funnel
ORDER BY device, step_order;

-- B. GA4's user funnel (counts people, copied from a GA4 exploration)
SELECT device, step_name, active_users,
  ROUND(100.0 * active_users / NULLIF(LAG(active_users) OVER (PARTITION BY device ORDER BY step_order), 0), 1)           AS pct_of_previous_step,
  ROUND(100.0 * active_users / NULLIF(FIRST_VALUE(active_users) OVER (PARTITION BY device ORDER BY step_order), 0), 2)    AS pct_of_start
FROM funnel_ga4
WHERE device <> 'smart tv'   -- too few users to read
ORDER BY device, step_order;
