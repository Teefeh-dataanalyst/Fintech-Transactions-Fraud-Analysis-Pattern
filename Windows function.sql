#### Windows function(Pattern detection)

-- 3a. Running transaction total per account (window function)
-- Shows cumulative spend per account across the year
SELECT account_id, transaction_date, transaction_month, amount, transaction_status,
    ROUND(SUM(amount) OVER (PARTITION BY account_id 
        ORDER BY transaction_date, transaction_time
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2)       AS running_total,
    COUNT(*) OVER (PARTITION BY account_id)                  AS account_total_txns
FROM transactions
ORDER BY account_id, transaction_date, transaction_time;

-- 3b. Transaction rank per account by amount (window function)
-- Identifies the largest transaction per account
SELECT account_id, transaction_id, transaction_date, amount, transaction_status,
    RANK() OVER (PARTITION BY account_id ORDER BY amount DESC)         AS amount_rank
FROM transactions
ORDER BY account_id, amount_rank;

-- 3c. Velocity detection — transactions within 60 minutes of previous
-- Core fraud detection pattern
SELECT t1.account_id, t1.transaction_id     AS current_txn, t1.transaction_date, t1.transaction_time,t1.amount     AS current_amount, t1.transaction_status   AS current_status,
    t2.transaction_id          AS previous_txn, t2.transaction_time    AS previous_time, t2.amount         AS previous_amount,
    TIMESTAMPDIFF(MINUTE, TIMESTAMP(t2.transaction_date, t2.transaction_time), TIMESTAMP(t1.transaction_date, t1.transaction_time))         AS minutes_apart
FROM transactions t1
JOIN transactions t2 
    ON  t1.account_id       = t2.account_id
    AND t1.transaction_id  != t2.transaction_id
    AND t1.transaction_date = t2.transaction_date
    AND TIMESTAMPDIFF(MINUTE, TIMESTAMP(t2.transaction_date, t2.transaction_time), TIMESTAMP(t1.transaction_date, t1.transaction_time)) BETWEEN 1 AND 60
ORDER BY t1.account_id, t1.transaction_date, minutes_apart;

-- 3d. Late night transaction pattern (between midnight and 5am)
-- High correlation with fraud in this dataset
SELECT t.account_id, a.full_name, a.risk_tier, t.transaction_id, t.transaction_date, t.transaction_time, t.amount, t.transaction_status, m.merchant_name, m.merchant_category
FROM transactions t
JOIN accounts  a ON t.account_id  = a.account_id
JOIN merchants m ON t.merchant_id = m.merchant_id
WHERE HOUR(t.transaction_time) BETWEEN 0 AND 4
ORDER BY t.amount DESC;

-- 3e. Account risk scoring - composite score per account
-- Assigns a risk score based on multiple fraud signals
SELECT a.account_id, a.full_name, a.risk_tier, a.kyc_status, a.account_status, COUNT(t.transaction_id)     AS total_transactions,
    SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END)                     AS flagged_count,
    SUM(CASE WHEN HOUR(t.transaction_time) BETWEEN 0 AND 4 THEN 1 ELSE 0 END)     AS late_night_txns,
    SUM(CASE WHEN t.amount > 100000 THEN 1 ELSE 0 END)                     AS high_value_txns,
    -- Risk score calculation
    ROUND((SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 3 +SUM(CASE WHEN HOUR(t.transaction_time) BETWEEN 0 AND 4 THEN 1 ELSE 0 END) * 2 +
        SUM(CASE WHEN t.amount > 100000 THEN 1 ELSE 0 END) * 2 +
        CASE WHEN a.kyc_status = 'Unverified' THEN 5
             WHEN a.kyc_status = 'Pending'    THEN 2
             ELSE 0 END +
        CASE WHEN a.account_status = 'Suspended' THEN 4
             ELSE 0 END
    ), 0)              AS composite_risk_score,
    -- Risk label based on score
    CASE 
        WHEN (
            SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 3 +
            SUM(CASE WHEN HOUR(t.transaction_time) BETWEEN 0 AND 4 THEN 1 ELSE 0 END) * 2 +
            SUM(CASE WHEN t.amount > 100000 THEN 1 ELSE 0 END) * 2 +
            CASE WHEN a.kyc_status  = 'Unverified' THEN 5
                 WHEN a.kyc_status  = 'Pending'    THEN 2
                 ELSE 0 END +
            CASE WHEN a.account_status = 'Suspended' THEN 4
                 ELSE 0 END
        ) >= 20 THEN 'Critical'
        WHEN (
            SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 3 +
            SUM(CASE WHEN HOUR(t.transaction_time) 
                     BETWEEN 0 AND 4 THEN 1 ELSE 0 END) * 2 +
            SUM(CASE WHEN t.amount > 100000 THEN 1 ELSE 0 END) * 2 +
            CASE WHEN a.kyc_status  = 'Unverified' THEN 5
                 WHEN a.kyc_status  = 'Pending'    THEN 2
                 ELSE 0 END +
            CASE WHEN a.account_status = 'Suspended' THEN 4
                 ELSE 0 END
        ) >= 10 THEN 'High'
        WHEN (
            SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 3 +
            SUM(CASE WHEN HOUR(t.transaction_time) BETWEEN 0 AND 4 THEN 1 ELSE 0 END) * 2 +
            SUM(CASE WHEN t.amount > 100000 THEN 1 ELSE 0 END) * 2 +
            CASE WHEN a.kyc_status  = 'Unverified' THEN 5
                 WHEN a.kyc_status  = 'Pending'    THEN 2
                 ELSE 0 END +
            CASE WHEN a.account_status = 'Suspended' THEN 4
                 ELSE 0 END
        ) >= 5  THEN 'Medium'
        ELSE 'Low'
    END                 AS risk_label
FROM accounts a
LEFT JOIN transactions t ON a.account_id = t.account_id
GROUP BY a.account_id, a.full_name, a.risk_tier, a.kyc_status, a.account_status
ORDER BY composite_risk_score DESC;

-- 3f. Above-average transaction amounts per merchant category (subquery)
-- Identifies outlier transactions within each category
SELECT t.transaction_id, t.account_id,m.merchant_name,m.merchant_category,t.amount,t.transaction_status,
    ROUND(cat_avg.avg_amount, 2)       AS category_avg_amount,
    ROUND(t.amount - cat_avg.avg_amount, 2)         AS amount_above_avg
FROM transactions t
JOIN merchants m ON t.merchant_id = m.merchant_id
JOIN (
    SELECT m2.merchant_category, AVG(t2.amount)   AS avg_amount
    FROM transactions t2
    JOIN merchants m2 ON t2.merchant_id = m2.merchant_id
    GROUP BY m2.merchant_category
) cat_avg ON m.merchant_category = cat_avg.merchant_category
WHERE t.amount > cat_avg.avg_amount * 1.5
ORDER BY amount_above_avg DESC;
