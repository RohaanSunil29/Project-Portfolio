-- 00_raw_tables.sql
-- Empty staging tables that mirror the three CSV files. Every column is TEXT,
-- so the import never fails on an odd date or number format; cleaning happens in 01_load.sql.

DROP TABLE IF EXISTS raw_daily_traffic, raw_monthly_items, raw_funnel_ga4;

CREATE TABLE raw_daily_traffic (
  "Date" TEXT, "Session default channel group" TEXT, "Device category" TEXT,
  "New / returning" TEXT, "Sessions" TEXT, "Engaged sessions" TEXT, "Add to carts" TEXT,
  "Checkouts" TEXT, "Ecommerce purchases" TEXT, "Purchase revenue" TEXT
);

CREATE TABLE raw_monthly_items (
  "Year month" TEXT, "Item category" TEXT, "Item name" TEXT, "Items viewed" TEXT,
  "Items added to cart" TEXT, "Items purchased" TEXT, "Item revenue" TEXT
);

CREATE TABLE raw_funnel_ga4 (device TEXT, step_order TEXT, step_name TEXT, active_users TEXT);

-- Next: import the CSVs into these tables (pgAdmin: right-click table > Import/Export Data, header on).
