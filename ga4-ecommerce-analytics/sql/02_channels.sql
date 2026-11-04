-- 02_channels.sql
-- Which channels bring buyers, not just visitors? (1 Oct 2025 - 30 Sep 2026)

-- 1. One row per channel and device, with the key KPIs
DROP TABLE IF EXISTS channel_summary;
CREATE TABLE channel_summary AS
SELECT
  channel,
  device,
  SUM(sessions)  AS sessions,
  SUM(purchases) AS purchases,
  SUM(revenue)   AS revenue,
  ROUND(100.0 * SUM(purchases) / NULLIF(SUM(sessions), 0), 2) AS conversion_rate_pct,
  ROUND(SUM(revenue) / NULLIF(SUM(sessions), 0), 2)           AS revenue_per_session,
  ROUND(SUM(revenue) / NULLIF(SUM(purchases), 0), 2)          AS avg_order_value
FROM traffic
WHERE dt BETWEEN '2025-10-01' AND '2026-09-30'
GROUP BY channel, device;

-- 2. Share of sessions vs share of revenue, and the value index
--    value index = revenue share / session share (above 1 = visits worth more than average)
SELECT
  channel,
  ROUND(100.0 * SUM(sessions) / SUM(SUM(sessions)) OVER (), 1) AS pct_of_sessions,
  ROUND(100.0 * SUM(revenue)  / SUM(SUM(revenue))  OVER (), 1) AS pct_of_revenue,
  ROUND((SUM(revenue) / SUM(SUM(revenue)) OVER ())
      / NULLIF(SUM(sessions) / SUM(SUM(sessions)) OVER (), 0), 2) AS value_index
FROM channel_summary
GROUP BY channel
ORDER BY pct_of_revenue DESC;

-- 3. Conversion rate by device inside each channel (is mobile worse everywhere?)
SELECT channel, device, sessions, conversion_rate_pct
FROM channel_summary
WHERE sessions >= 1000   -- ignore tiny samples
ORDER BY channel, conversion_rate_pct DESC;
