# Fintech-Transactions-And-Fraud-Analysis-Pattern

# Project Overview

This project delivers an end-to-end fraud pattern analysis for a Nigerian fintech payment platform processing transactions across multiple channels (Mobile, Web, USSD, POS, and ATM). Starting from a relational MySQL database designed and built from scratch, the project covers full database architecture, data insertion, advanced SQL analysis including window functions and composite risk scoring, SQL view creation, and an interactive Power BI dashboard connected directly to the MySQL views.The analysis spans a 12-month observation window (January 2024 – December 2024) and examines fraud concentration patterns across merchant categories, transaction channels, device types, account risk tiers, and time-of-day behaviour.

# Tools & Technologies

MySQL 8.0 - database design, DDL scripts, data insertion, KPI queries, advanced SQL, view creation
MySQL Workbench - query execution and schema management
Power BI Desktop - MySQL connector, DAX measures, dashboard design
Power Query (M) - data type enforcement on loaded views


# Key Findings

Overall Fraud : Of 170 total transactions, 54 were flagged; a fraud rate of 31.8%. Total flagged transaction value amounts to a significant portion of platform volume, concentrated among a small number of repeat offenders. The system-generated flag confirmation rate is high, validating the automated detection logic.


Accounts Driving Fraud:
Six accounts account for the majority of confirmed fraud events — ACC004, ACC007, ACC012, ACC017, ACC022, and ACC024. All six share a common profile: High risk tier, Unverified or Suspended status, Android mobile device, and transactions exclusively through the unverified merchant MER019. This clustering is the most significant finding in the dataset.


Time-of-Day Pattern:
All flagged transactions occur between midnight and 05:00. Zero fraud events are recorded during business hours. This late-night concentration is the single strongest predictive signal in the dataset and would serve as a primary rule in a real-time fraud detection engine.


Merchant Concentration:
MER019 -an unverified merchant categorised under Transfers is involved in 100% of flagged transactions. Every other merchant in the dataset has a 0% fraud rate. This is a textbook unverified merchant fraud pattern where a single bad actor merchant is used as the conduit for fraudulent activity.


Channel and Device Pattern:
Mobile channel combined with Android device type carries the entire fraud burden in this dataset. Web, POS, USSD, and iOS transactions show zero fraud events. This aligns with the account profile finding all fraud originates from the same channel-device combination.


Velocity Events:
Two transaction pairs were detected within 60 minutes of each other on the same account — ACC004 on January 12 executed two transactions 3 minutes apart totalling ₦160,000. Both were flagged and subsequently confirmed as fraud.


Flag Resolution:
Of 54 fraud flags: 35 confirmed fraud, 11 under review, and 8 false positives. System-generated flags have a higher confirmation rate than analyst or customer-raised flags, validating the automated detection logic built into the platform.


Composite Risk Scores:
The risk scoring query ranks ACC004 and ACC007 as Critical risk both have accumulated the maximum combination of flagged transactions, late night activity, high value transactions, and unverified KYC status. These two accounts represent the highest priority for investigation and account suspension.

