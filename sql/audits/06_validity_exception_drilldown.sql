/*******************************************************************************
 * SCRIPT NAME:    06_validity_exception_drilldown.sql
 * DOMAIN:         Retail Lending & Risk Analytics
 * TARGET ASSET:   credit_applications (Ingestion Staging Layer)
 * REGULATION:     OSFI Guideline E-21 / BCBS 239 Principle 3 (Data Accuracy & Remediation)
 *
 * PURPOSE:        Micro-level root cause analysis (RCA) and triage query. Isolates
 *                 individual records breaching domain rules, calculates multi-defect
 *                 severity scores, and dynamically compiles diagnostic error lists
 *                 for operational remediation and upstream engineering escalation.
 *
 * CRITICALITY:    Medium-High (Operational Remediation & Source System Feedback)
 * TARGET CONSUMER:Data Stewards, Quality Analysts, Ingestion Pipeline Engineers
 * CADENCE:        On-demand / Triggered upon VALIDITY_BREACH_ALERT
 *
 * OWNER/STEWARD:  Risk Data Governance Team
 *
 * ARCHITECTURE:
 *   1. evaluated_records : Scan staging ingestion and flag atomic domain breaches.
 *   2. Final Extraction  : Compute severity, concatenate error list, and filter 
 *                          defects in a single pass without redundant CTE chaining.
 *******************************************************************************/

-- =============================================================================
-- STEP 1: SCAN STAGING INGESTION & EVALUATE ATOMIC DOMAIN BREACHES PER RECORD
-- =============================================================================
WITH evaluated_records AS (
    SELECT
        application_id,
        customer_id,
        annual_income,
        employment_status,
        credit_score,
        postal_code,

        -- Rule 1: Negative income breach flag (Exclude NULLs)
        CASE 
            WHEN annual_income IS NOT NULL AND annual_income < 0 
            THEN 1 
            ELSE 0 
        END AS is_invalid_income,

        -- Rule 2: Credit score out-of-bounds flag (Standard: 300 to 900 Canadian FICO/Beacon scale)
        CASE 
            WHEN credit_score IS NOT NULL AND credit_score NOT BETWEEN 300 AND 900 
            THEN 1 
            ELSE 0 
        END AS is_invalid_credit_score,

        -- Rule 3: Unapproved employment status enum flag (Trim whitespace prior to set evaluation)
        CASE 
            WHEN employment_status IS NOT NULL 
                 AND TRIM(employment_status) != '' 
                 AND TRIM(employment_status) NOT IN (
                     'Full-time', 'Part-time', 'Self-employed', 'Contract', 'Retired', 'Unemployed'
                 )
            THEN 1 
            ELSE 0 
        END AS is_invalid_employment_status,

        -- Rule 4: Canadian postal code format breach flag (Strict Canada Post regex compliance)
        CASE 
            WHEN postal_code IS NOT NULL 
                 AND TRIM(postal_code) != '' 
                 AND postal_code NOT REGEXP '^[A-CEGHJ-NPR-TVXY][0-9][A-CEGHJ-NPR-TV-Z] ?[0-9][A-CEGHJ-NPR-TV-Z][0-9]$'
            THEN 1 
            ELSE 0 
        END AS is_invalid_postal_code

    FROM credit_applications
)

-- =============================================================================
-- FINAL STEP: PRIORITIZED EXCEPTION TRIAGE EXTRACTION FOR OPERATIONAL REMEDIATION
-- =============================================================================
SELECT
    application_id,
    customer_id,
    annual_income,
    employment_status,
    credit_score,
    postal_code,

    -- Multi-defect severity calculation
    (is_invalid_income + is_invalid_credit_score + is_invalid_employment_status + is_invalid_postal_code) AS total_validity_defects,

    -- Dynamic diagnostic audit trail using NULL-skipping CONCAT_WS
    CONCAT_WS(', ',
        CASE WHEN is_invalid_income = 1 THEN 'NEGATIVE_INCOME' END,
        CASE WHEN is_invalid_credit_score = 1 THEN 'SCORE_OUT_OF_BOUNDS' END,
        CASE WHEN is_invalid_employment_status = 1 THEN 'INVALID_EMPLOYMENT_ENUM' END,
        CASE WHEN is_invalid_postal_code = 1 THEN 'INVALID_POSTAL_REGEX' END
    ) AS breached_rules_list

FROM evaluated_records
WHERE (is_invalid_income + is_invalid_credit_score + is_invalid_employment_status + is_invalid_postal_code) > 0
ORDER BY total_validity_defects DESC, application_id ASC;