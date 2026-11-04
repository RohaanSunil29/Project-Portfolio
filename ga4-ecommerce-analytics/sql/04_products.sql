-- 04_products.sql
-- Which products and product types earn their place in the range? (1 Oct 2025 - 30 Sep 2026)

-- 1. One row per product.
--    GA4 tags a product's views and purchases with different categories, so we group by name only.
DROP TABLE IF EXISTS product_summary;
CREATE TABLE product_summary AS
SELECT
  product,
  SUM(views)         AS views,
  SUM(added_to_cart) AS added_to_cart,
  SUM(units_sold)    AS units_sold,
  ROUND(SUM(revenue), 2) AS revenue,
  ROUND(100.0 * SUM(added_to_cart) / NULLIF(SUM(views), 0), 1) AS view_to_cart_pct
FROM items
WHERE month BETWEEN '2025-10-01' AND '2026-09-01'
  AND product NOT IN ('(not set)', '')
GROUP BY product
HAVING SUM(views) >= 100;   -- skip products with too few views to judge

-- 2. Product type from keywords in the product name.
--    GA4's own categories are store collections (e.g. "New", "Shop by Brand"), not product types.
--    Lower priority number wins when several keywords match (e.g. "Kids Hoodie" -> Kids).
DROP TABLE IF EXISTS type_keywords;
CREATE TABLE type_keywords (priority INT, keyword TEXT, product_type TEXT);
INSERT INTO type_keywords VALUES
  (1,  'kids',       'Kids'),
  (1,  'youth',      'Kids'),
  (1,  'toddler',    'Kids'),
  (1,  'onesie',     'Kids'),
  (2,  'sweatshirt', 'Sweatshirts & jackets'),
  (2,  'hoodie',     'Sweatshirts & jackets'),
  (2,  'jacket',     'Sweatshirts & jackets'),
  (2,  'pullover',   'Sweatshirts & jackets'),
  (2,  'sweater',    'Sweatshirts & jackets'),
  (2,  'zip',        'Sweatshirts & jackets'),
  (2,  'fleece',     'Sweatshirts & jackets'),
  (2,  'vest',       'Sweatshirts & jackets'),
  (3,  'beanie',     'Hats, socks & scarves'),
  (3,  'hat',        'Hats, socks & scarves'),
  (3,  'cap',        'Hats, socks & scarves'),
  (3,  'sock',       'Hats, socks & scarves'),
  (3,  'scarf',      'Hats, socks & scarves'),
  (4,  'bottle',     'Drinkware'),
  (4,  'mug',        'Drinkware'),
  (4,  'tumbler',    'Drinkware'),
  (4,  'cup',        'Drinkware'),
  (4,  'flask',      'Drinkware'),
  (5,  'bag',        'Bags'),
  (5,  'backpack',   'Bags'),
  (5,  'tote',       'Bags'),
  (5,  'duffel',     'Bags'),
  (5,  'pouch',      'Bags'),
  (6,  'collectible','Collectibles & toys'),
  (6,  'brick',      'Collectibles & toys'),
  (6,  'plush',      'Collectibles & toys'),
  (6,  'toy',        'Collectibles & toys'),
  (6,  'puzzle',     'Collectibles & toys'),
  (7,  'notebook',   'Stationery & books'),
  (7,  'journal',    'Stationery & books'),
  (7,  'pen',        'Stationery & books'),
  (7,  'pencil',     'Stationery & books'),
  (7,  'sticker',    'Stationery & books'),
  (7,  'book',       'Stationery & books'),
  (7,  'magnet',     'Stationery & books'),
  (8,  'yoga',       'Sports & outdoor'),
  (8,  'frisbee',    'Sports & outdoor'),
  (8,  'golf',       'Sports & outdoor'),
  (8,  'picnic',     'Sports & outdoor'),
  (8,  'camp',       'Sports & outdoor'),
  (9,  'tee',        'T-shirts & other apparel'),
  (9,  'shirt',      'T-shirts & other apparel'),
  (9,  'polo',       'T-shirts & other apparel'),
  (9,  'tank',       'T-shirts & other apparel'),
  (10, 'lanyard',    'Accessories & gifts'),
  (10, 'keychain',   'Accessories & gifts'),
  (10, 'pin',        'Accessories & gifts'),
  (10, 'patch',      'Accessories & gifts'),
  (10, 'case',       'Accessories & gifts'),
  (10, 'umbrella',   'Accessories & gifts'),
  (10, 'blanket',    'Accessories & gifts');

-- 3. Product table used by Power BI: each product with its type and group.
--    Group = how a product compares with the MEDIAN product of the same type family:
--    views above/below the median x view-to-cart rate above/below the median.
--    Only apparel is grouped: item-view tracking is incomplete for other types
--    (add-to-carts exceed views for many of them), so their view-to-cart rates aren't comparable.
DROP TABLE IF EXISTS product_groups;
CREATE TABLE product_groups AS
WITH typed AS (
  SELECT DISTINCT ON (p.product)             -- keep the best (lowest priority) match per product
    p.*, COALESCE(k.product_type, 'Other') AS product_type
  FROM product_summary p
  LEFT JOIN type_keywords k ON LOWER(p.product) ~ ('\m' || k.keyword)   -- keyword at the start of a word
  ORDER BY p.product, k.priority
),
medians AS (
  SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY views)            AS med_views,
         PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY view_to_cart_pct) AS med_v2c
  FROM typed
  WHERE product_type IN ('Sweatshirts & jackets', 'T-shirts & other apparel')
)
SELECT t.*,
  CASE
    WHEN t.product_type NOT IN ('Sweatshirts & jackets', 'T-shirts & other apparel') THEN 'Not compared'
    WHEN t.views >= m.med_views AND t.view_to_cart_pct >= m.med_v2c THEN 'Star'
    WHEN t.views >= m.med_views                                     THEN 'High interest, low conversion'
    WHEN t.view_to_cart_pct >= m.med_v2c                            THEN 'Hidden gem'
    ELSE 'Underperformer'
  END AS product_group
FROM typed t CROSS JOIN medians m;

-- 4. Revenue by product type: share of the range vs share of revenue
SELECT product_type,
  COUNT(*) AS products,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_range,
  ROUND(SUM(revenue))                                AS revenue,
  ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS pct_of_revenue,
  ROUND(SUM(revenue) / COUNT(*))                     AS revenue_per_product
FROM product_groups
GROUP BY product_type
ORDER BY revenue DESC;

-- 5. Top 10 apparel products by views, with their group
SELECT product, product_type, views, view_to_cart_pct, revenue, product_group
FROM product_groups
WHERE product_group <> 'Not compared'
ORDER BY views DESC
LIMIT 10;
