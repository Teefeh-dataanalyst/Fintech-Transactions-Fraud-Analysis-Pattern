-- ============================================================
-- Project:  Fintech Transaction & Fraud Pattern Analysis
-- File:     01_create_tables.sql
-- Purpose:  DDL scripts to create all four database tables
-- ============================================================

CREATE DATABASE fintech_fraud;
USE fintech_fraud;

-- Table 1: accounts
CREATE TABLE accounts (
    account_id          VARCHAR(10)     PRIMARY KEY,
    full_name           VARCHAR(100)    NOT NULL,
    phone_number        VARCHAR(15)     NOT NULL UNIQUE,
    email               VARCHAR(100)    NOT NULL UNIQUE,
    region              VARCHAR(50)     NOT NULL,
    state               VARCHAR(50)     NOT NULL,
    account_type        VARCHAR(20)     NOT NULL,
    account_status      VARCHAR(20)     NOT NULL,
    registration_date   DATE            NOT NULL,
    kyc_status          VARCHAR(20)     NOT NULL,
    risk_tier           VARCHAR(20)     NOT NULL
);

-- Table 2: merchants
CREATE TABLE merchants (
    merchant_id         VARCHAR(10)     PRIMARY KEY,
    merchant_name       VARCHAR(100)    NOT NULL,
    merchant_category   VARCHAR(50)     NOT NULL,
    region              VARCHAR(50)     NOT NULL,
    state               VARCHAR(50)     NOT NULL,
    is_verified         TINYINT(1)      NOT NULL DEFAULT 1
);

-- Table 3: transactions
CREATE TABLE transactions (
    transaction_id      VARCHAR(15)     PRIMARY KEY,
    account_id          VARCHAR(10)     NOT NULL,
    merchant_id         VARCHAR(10)     NOT NULL,
    transaction_date    DATE            NOT NULL,
    transaction_time    TIME            NOT NULL,
    transaction_month   VARCHAR(7)      NOT NULL,
    transaction_type    VARCHAR(20)     NOT NULL,
    channel             VARCHAR(20)     NOT NULL,
    amount              DECIMAL(12,2)   NOT NULL,
    transaction_status  VARCHAR(20)     NOT NULL,
    failure_reason      VARCHAR(100),
    device_type         VARCHAR(20)     NOT NULL,
    FOREIGN KEY (account_id)  REFERENCES accounts(account_id),
    FOREIGN KEY (merchant_id) REFERENCES merchants(merchant_id)
);

-- Table 4: fraud_flags
CREATE TABLE fraud_flags (
    flag_id             VARCHAR(15)     PRIMARY KEY,
    transaction_id      VARCHAR(15)     NOT NULL,
    account_id          VARCHAR(10)     NOT NULL,
    flag_date           DATE            NOT NULL,
    flag_reason         VARCHAR(100)    NOT NULL,
    flag_status         VARCHAR(20)     NOT NULL,
    flagged_by          VARCHAR(20)     NOT NULL,
    resolution_date     DATE,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    FOREIGN KEY (account_id)     REFERENCES accounts(account_id)
);