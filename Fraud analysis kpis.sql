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
