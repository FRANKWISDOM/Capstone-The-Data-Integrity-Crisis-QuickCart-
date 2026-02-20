-- =========================================
-- STEP 1: Deduplicate Successful Payments
-- =========================================

WITH deduplicated_payments AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY order_id
               ORDER BY attempted_at DESC
           ) AS rn
    FROM payments
    WHERE status = 'SUCCESS'
),

clean_internal_sales AS (
    SELECT 
        order_id,
        amount_cents
    FROM deduplicated_payments
    WHERE rn = 1
      AND order_id IS NOT NULL
),

internal_totals AS (
    SELECT 
        COUNT(*) AS total_successful_sales,
        COALESCE(SUM(amount_cents), 0) / 100.0 AS total_internal_amount_usd
    FROM clean_internal_sales
),

bank_totals AS (
    SELECT 
        COUNT(*) AS total_settled_transactions,
        COALESCE(SUM(settled_amount_cents), 0) / 100.0 AS total_bank_amount_usd
    FROM bank_settlements
),

orphan_payments AS (
    SELECT *
    FROM payments
    WHERE order_id IS NULL
      AND status = 'SUCCESS'
)

-- =========================================
-- FINAL RECONCILIATION OUTPUT
-- =========================================

SELECT 
    i.total_successful_sales,
    i.total_internal_amount_usd,
    b.total_settled_transactions,
    b.total_bank_amount_usd,
    (i.total_internal_amount_usd - b.total_bank_amount_usd) AS discrepancy_gap_usd
FROM internal_totals i,
     bank_totals b;