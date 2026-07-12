#### Transaction volume and Revenue KPIs

-- 1a. Monthly transaction trend
SELECT transaction_month, COUNT(*)   AS total_transactions,
    SUM(CASE WHEN transaction_status = 'Success'  THEN 1 ELSE 0 END)    AS successful,
    SUM(CASE WHEN transaction_status = 'Failed'   THEN 1 ELSE 0 END)    AS failed,
    SUM(CASE WHEN transaction_status = 'Flagged'  THEN 1 ELSE 0 END)    AS flagged,
    SUM(CASE WHEN transaction_status = 'Reversed' THEN 1 ELSE 0 END)    AS reversed,
    ROUND(SUM(CASE WHEN transaction_status = 'Success' THEN amount ELSE 0 END), 2)     AS successful_revenue,
    ROUND(SUM(CASE WHEN transaction_status = 'Flagged' THEN amount ELSE 0 END), 2)     AS flagged_amount
FROM transactions
GROUP BY transaction_month
ORDER BY transaction_month;

-- 1b. Transaction volume and value by channel
SELECT channel, COUNT(*)  AS total_transactions,
    ROUND(SUM(amount), 2)   AS total_amount,
    ROUND(AVG(amount), 2)   AS avg_transaction_value,
    SUM(CASE WHEN transaction_status = 'Flagged'  THEN 1 ELSE 0 END)      AS flagged_count,
    ROUND(SUM(CASE WHEN transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)     AS flag_rate_pct
FROM transactions
GROUP BY channel
ORDER BY total_amount DESC;

-- 1c. Transaction volume by device type
SELECT device_type, COUNT(*)     AS total_transactions,
    SUM(CASE WHEN transaction_status = 'Flagged'  THEN 1 ELSE 0 END)      AS flagged_count,
    ROUND(SUM(CASE WHEN transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)   AS flag_rate_pct,
    ROUND(AVG(amount), 2)       AS avg_amount
FROM transactions
GROUP BY device_type
ORDER BY flagged_count DESC;

-- 1d. Revenue by merchant category
SELECT m.merchant_category, COUNT(t.transaction_id)         AS total_transactions,
    ROUND(SUM(CASE WHEN t.transaction_status = 'Success' THEN t.amount ELSE 0 END), 2)    AS successful_revenue,
    SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END)                     AS flagged_count,
    ROUND(AVG(t.amount), 2)                    AS avg_transaction_value
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
GROUP BY m.merchant_category
ORDER BY flagged_count DESC;
