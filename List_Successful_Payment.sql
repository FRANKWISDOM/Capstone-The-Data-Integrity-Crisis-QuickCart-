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
SELECT *
FROM ranked_payments
WHERE rn = 1;