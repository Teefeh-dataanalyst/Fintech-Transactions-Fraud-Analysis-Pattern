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



### FRAUD ANALYSIS KPIs

-- 2a. Overall fraud rate
SELECT COUNT(*)        AS total_transactions,
    SUM(CASE WHEN transaction_status = 'Flagged'  THEN 1 ELSE 0 END)   AS flagged_count,
    ROUND(SUM(CASE WHEN transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)   AS fraud_rate_pct,
    ROUND(SUM(CASE WHEN transaction_status = 'Flagged' THEN amount ELSE 0 END), 2)      AS total_flagged_amount
FROM transactions;

-- 2b. Fraud flag status breakdown
SELECT flag_status, COUNT(*)       AS flag_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)     AS pct_of_flags,
    COUNT(CASE WHEN resolution_date IS NOT NULL THEN 1 END)      AS resolved_count,
    COUNT(CASE WHEN resolution_date IS NULL THEN 1 END)         AS unresolved_count
FROM fraud_flags
GROUP BY flag_status;

-- 2c. Fraud by flag reason
SELECT flag_reason, COUNT(*)    AS occurrence_count,
    SUM(CASE WHEN flag_status = 'Confirmed Fraud' THEN 1 ELSE 0 END)    AS confirmed_fraud,
    SUM(CASE WHEN flag_status = 'False Positive'  THEN 1 ELSE 0 END)    AS false_positives,
    SUM(CASE WHEN flag_status = 'Under Review'    THEN 1 ELSE 0 END)    AS under_review
FROM fraud_flags
GROUP BY flag_reason
ORDER BY confirmed_fraud DESC;

-- 2d. Fraud by flagged_by source
SELECT flagged_by, COUNT(*)    AS flags_raised,
    SUM(CASE WHEN flag_status = 'Confirmed Fraud' THEN 1 ELSE 0 END)        AS confirmed,
    ROUND(SUM(CASE WHEN flag_status = 'Confirmed Fraud' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)    AS confirmation_rate_pct
FROM fraud_flags
GROUP BY flagged_by
ORDER BY confirmation_rate_pct DESC;

-- 2e. High risk accounts — fraud profile
SELECT a.account_id, a.full_name, a.account_status, a.risk_tier, a.kyc_status,COUNT(t.transaction_id)          AS total_transactions,
    SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END)                     AS flagged_transactions,
    ROUND(SUM(CASE WHEN t.transaction_status = 'Flagged' THEN t.amount ELSE 0 END), 2)    AS total_flagged_amount, COUNT(f.flag_id)       AS total_flags,
    SUM(CASE WHEN f.flag_status = 'Confirmed Fraud' THEN 1 ELSE 0 END)          AS confirmed_fraud_count
FROM accounts a
LEFT JOIN transactions t  ON a.account_id = t.account_id
LEFT JOIN fraud_flags f   ON a.account_id = f.account_id
GROUP BY a.account_id, a.full_name, a.account_status, a.risk_tier, a.kyc_status
HAVING flagged_transactions > 0
ORDER BY confirmed_fraud_count DESC;


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


####### POWER BI VIEWS

-- View 1: Monthly fraud summary
CREATE VIEW vw_monthly_fraud_summary AS
SELECT t.transaction_month,COUNT(t.transaction_id)    AS total_transactions,
    SUM(CASE WHEN t.transaction_status = 'Success'  THEN 1 ELSE 0 END)      AS successful_count,
    SUM(CASE WHEN t.transaction_status = 'Failed'   THEN 1 ELSE 0 END)      AS failed_count,
    SUM(CASE WHEN t.transaction_status = 'Flagged'  THEN 1 ELSE 0 END)      AS flagged_count,
    SUM(CASE WHEN t.transaction_status = 'Reversed' THEN 1 ELSE 0 END)      AS reversed_count,
    ROUND(SUM(CASE WHEN t.transaction_status = 'Success' THEN t.amount ELSE 0 END), 2)        AS successful_revenue,
    ROUND(SUM(CASE WHEN t.transaction_status = 'Flagged' THEN t.amount ELSE 0 END), 2)        AS flagged_amount,
    ROUND(SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2)             AS fraud_rate_pct,
    -- Time band breakdown
    SUM(CASE WHEN HOUR(t.transaction_time) BETWEEN 0 AND 4   THEN 1 ELSE 0 END)             AS late_night_txns,
    SUM(CASE WHEN HOUR(t.transaction_time) BETWEEN 5 AND 11  THEN 1 ELSE 0 END)             AS morning_txns,
    SUM(CASE WHEN HOUR(t.transaction_time) BETWEEN 12 AND 17 THEN 1 ELSE 0 END)             AS afternoon_txns,
    SUM(CASE WHEN HOUR(t.transaction_time) BETWEEN 18 AND 23 THEN 1 ELSE 0 END)             AS evening_txns,
    -- Late night flagged specifically
    SUM(CASE WHEN HOUR(t.transaction_time) BETWEEN 0 AND 4 AND t.transaction_status = 'Flagged' THEN 1 ELSE 0 END)     AS late_night_flagged
FROM transactions t
GROUP BY t.transaction_month;

-- View 2: Account risk profile
CREATE VIEW vw_account_risk_profile AS
SELECT a.account_id,a.full_name,a.region,a.state,a.account_type,a.account_status,a.kyc_status,a.risk_tier,a.registration_date,
    COUNT(t.transaction_id)           AS total_transactions,
    ROUND(SUM(t.amount), 2)           AS total_transaction_value,
    SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END)     AS flagged_count,
    ROUND(SUM(CASE WHEN t.transaction_status = 'Flagged' THEN t.amount ELSE 0 END), 2)    AS flagged_amount,
    COUNT(f.flag_id)                                AS total_flags,
    SUM(CASE WHEN f.flag_status = 'Confirmed Fraud' THEN 1 ELSE 0 END)                     AS confirmed_fraud_count,
    SUM(CASE WHEN f.flag_status = 'Under Review'  THEN 1 ELSE 0 END)                     AS under_review_count
FROM accounts a
LEFT JOIN transactions t ON a.account_id = t.account_id
LEFT JOIN fraud_flags f  ON a.account_id = f.account_id
GROUP BY a.account_id, a.full_name, a.region, a.state,a.account_type, a.account_status, a.kyc_status,a.risk_tier, a.registration_date;

-- View 3: Merchant fraud profile
CREATE VIEW vw_merchant_fraud_profile AS
SELECT m.merchant_id,m.merchant_name,m.merchant_category,m.region,m.is_verified,
    COUNT(t.transaction_id)      AS total_transactions,
    ROUND(SUM(t.amount), 2)      AS total_transaction_value,
    ROUND(AVG(t.amount), 2)     AS avg_transaction_value,
    SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END)        AS flagged_count,
    ROUND(SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 100.0 / COUNT(t.transaction_id), 2)     AS fraud_rate_pct
FROM merchants m
LEFT JOIN transactions t ON m.merchant_id = t.merchant_id
GROUP BY m.merchant_id, m.merchant_name, m.merchant_category, m.region, m.is_verified;

-- View 4: Channel and device performance
CREATE VIEW vw_channel_device_performance AS
SELECT channel,device_type, COUNT(*)    AS total_transactions,
    ROUND(SUM(amount), 2)            AS total_amount,
    ROUND(AVG(amount), 2)            AS avg_amount,
    SUM(CASE WHEN transaction_status = 'Success'  THEN 1 ELSE 0 END)           AS successful,
    SUM(CASE WHEN transaction_status = 'Flagged'  THEN 1 ELSE 0 END)           AS flagged,
    ROUND(SUM(CASE WHEN transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)  AS fraud_rate_pct
FROM transactions
GROUP BY channel, device_type;


CREATE VIEW vw_time_pattern_analysis AS
SELECT 
    CASE 
        WHEN HOUR(t.transaction_time) BETWEEN 0  AND 4  THEN 'Late Night (00-04)'
        WHEN HOUR(t.transaction_time) BETWEEN 5  AND 11 THEN 'Morning (05-11)'
        WHEN HOUR(t.transaction_time) BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
        WHEN HOUR(t.transaction_time) BETWEEN 18 AND 23 THEN 'Evening (18-23)'
    END          AS time_band,
    CASE 
        WHEN HOUR(t.transaction_time) BETWEEN 0  AND 4  THEN 1
        WHEN HOUR(t.transaction_time) BETWEEN 5  AND 11 THEN 2
        WHEN HOUR(t.transaction_time) BETWEEN 12 AND 17 THEN 3
        WHEN HOUR(t.transaction_time) BETWEEN 18 AND 23 THEN 4
    END          AS time_band_sort,
    t.transaction_month,t.channel,t.device_type,COUNT(t.transaction_id)  AS total_transactions,
    SUM(CASE WHEN t.transaction_status = 'Flagged'  THEN 1 ELSE 0 END)              AS flagged_count,
    SUM(CASE WHEN t.transaction_status = 'Success'  THEN 1 ELSE 0 END)              AS successful_count,
    ROUND(SUM(CASE WHEN t.transaction_status = 'Flagged' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 2)             AS fraud_rate_pct,
    ROUND(SUM(t.amount), 2)        AS total_amount,
    ROUND(SUM(CASE WHEN t.transaction_status = 'Flagged' THEN t.amount ELSE 0 END), 2)        AS flagged_amount
FROM transactions t
GROUP BY 
    CASE 
        WHEN HOUR(t.transaction_time) BETWEEN 0  AND 4  THEN 'Late Night (00-04)'
        WHEN HOUR(t.transaction_time) BETWEEN 5  AND 11 THEN 'Morning (05-11)'
        WHEN HOUR(t.transaction_time) BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
        WHEN HOUR(t.transaction_time) BETWEEN 18 AND 23 THEN 'Evening (18-23)'
    END,
    CASE 
        WHEN HOUR(t.transaction_time) BETWEEN 0  AND 4  THEN 1
        WHEN HOUR(t.transaction_time) BETWEEN 5  AND 11 THEN 2
        WHEN HOUR(t.transaction_time) BETWEEN 12 AND 17 THEN 3
        WHEN HOUR(t.transaction_time) BETWEEN 18 AND 23 THEN 4
    END,t.transaction_month,t.channel,t.device_type;
    
    
CREATE VIEW vw_velocity_events AS
SELECT t1.account_id,a.full_name,a.risk_tier,a.kyc_status,t1.transaction_id               AS txn_id,
    t1.transaction_date               AS txn_date,
    t1.transaction_time               AS txn_time,
    t1.amount                         AS txn_amount,
    t1.transaction_status             AS txn_status,
    t2.transaction_id                 AS prev_txn_id,
    t2.transaction_time               AS prev_txn_time,
    t2.amount                         AS prev_txn_amount,
    TIMESTAMPDIFF(MINUTE,
        TIMESTAMP(t2.transaction_date, t2.transaction_time),
        TIMESTAMP(t1.transaction_date, t1.transaction_time)
    )                                                   AS minutes_apart,
    m.merchant_name,
    m.merchant_category,
    m.is_verified
FROM transactions t1
JOIN transactions t2
    ON  t1.account_id       = t2.account_id
    AND t1.transaction_id  != t2.transaction_id
    AND t1.transaction_date = t2.transaction_date
    AND TIMESTAMPDIFF(MINUTE,
            TIMESTAMP(t2.transaction_date, t2.transaction_time),
            TIMESTAMP(t1.transaction_date, t1.transaction_time)
        ) BETWEEN 1 AND 60
JOIN accounts  a ON t1.account_id  = a.account_id
JOIN merchants m ON t1.merchant_id = m.merchant_id;
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    