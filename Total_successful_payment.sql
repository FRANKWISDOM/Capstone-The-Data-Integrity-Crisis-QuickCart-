WITH ranked_payments AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY order_id
               ORDER BY attempted_at DESC
           ) AS rn
    FROM payments
    WHERE status = 'SUCCESS'
      AND order_id IS NOT NULL
)
SELECT 
    COUNT(*) AS total_successful_orders,
    SUM(amount_cents) / 100.0 AS total_successful_amount_usd
FROM ranked_payments
WHERE rn = 1;