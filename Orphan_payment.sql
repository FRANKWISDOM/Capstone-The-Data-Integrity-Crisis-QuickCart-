-- =========================================
-- STEP 1: Deduplicate Internal Sales
-- =========================================
WITH deduplicated_sales AS (
    SELECT *
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY order_id
                   ORDER BY attempted_at DESC
               ) AS rn
        FROM payments
        WHERE status = 'SUCCESS'
    ) sub
    WHERE rn = 1
),

-- =========================================
-- STEP 2: List Orphan Payments
-- =========================================
orphan_payments AS (
    SELECT 
        p.payment_id,
        p.order_id,
        p.amount_cents,
        p.attempted_at
    FROM payments p
    WHERE p.status = 'SUCCESS'
      AND (p.order_id IS NULL
           OR TRIM(CAST(p.order_id AS TEXT)) NOT IN (
                SELECT TRIM(CAST(order_id AS TEXT)) 
                FROM deduplicated_sales
           )
      )
),

-- =========================================
-- STEP 3: Summary Totals
-- =========================================
summary AS (
    SELECT 
        SUM(amount_cents) FILTER (WHERE order_id IS NOT NULL) AS total_sales_cents,
        SUM(amount_cents) FILTER (WHERE order_id IS NULL OR order_id NOT IN (
            SELECT order_id FROM deduplicated_sales
        )) AS total_orphan_cents,
        SUM(amount_cents) AS total_received_cents
    FROM payments
    WHERE status = 'SUCCESS'
)

-- =========================================
-- STEP 4: Final Output
-- =========================================
SELECT 
    'Internal Sales' AS category,
    order_id,
    amount_cents,
    attempted_at
FROM deduplicated_sales

UNION ALL

SELECT
    'Orphan Payment' AS category,
    order_id,
    amount_cents,
    attempted_at
FROM orphan_payments

UNION ALL

SELECT
    'SUMMARY' AS category,
    NULL AS order_id,
    total_received_cents AS amount_cents,
    NULL AS attempted_at
FROM summary;