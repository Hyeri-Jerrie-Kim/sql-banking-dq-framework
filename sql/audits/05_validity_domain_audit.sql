/*******************************************************************************
 * SCRIPT NAME:    05_validity_domain_audit.sql
 * DOMAIN:         Retail Lending & Risk Analytics
 * TARGET ASSET:   credit_applications (Ingestion Staging Layer)
 * REGULATION:     OSFI Guideline E-21 / BCBS 239 Principle 3 (Data Accuracy)
 *
* PURPOSE:         Macro batch-level SLA validation across critical data elements
 *                 (Income non-negativity, Canadian credit score bounds 300-900,
 *                 approved employment enums, and Canada Post regex standard).
 *                 Produces a single-row executive KPI summary to drive automated
 *                 pipeline circuit breakers.
 *
 * CRITICALITY:    High (Prevents invalid credit scoring model execution)
 * SLA / THRESHOLD:Domain Validity Breach Rate = 0.00% across all evaluated CDEs
 * CADENCE:        Hourly Micro-batch / Daily Post-Ingestion Trigger
 *
 * OWNER/STEWARD:  Risk Data Governance Team
 *
 * ARCHITECTURE:   
 *   1. evaluated_records   : Scan staging ingestion, apply 4 atomic non-null domain
 *                            rules, and assign binary breach indicators.
 *   2. dq_validity_summary : Single-pass metric aggregation reporting breach counts,
 *                            rates (%), multi-defect distribution, and SLA status.
 *******************************************************************************/

-- =============================================================================
-- STEP 1: SCAN STAGING INGESTION & FLAG ATOMIC DOMAIN BREACHES PER RECORD
-- =============================================================================
WITH evaluated_records AS (
    SELECT
        application_id,
        customer_id,

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
-- FINAL STEP: SINGLE-PASS DOMAIN VALIDITY AUDIT SUMMARY (SLA MONITORING)
-- =============================================================================
SELECT
    COUNT(*) AS total_records_evaluated,
    
    -- 1. Atomic Rule Breach Counts & Rates
    COALESCE(SUM(is_invalid_income), 0) AS invalid_income_cnt,
    ROUND(AVG(is_invalid_income * 100.0), 2) AS invalid_income_pct,
    
    COALESCE(SUM(is_invalid_credit_score), 0) AS invalid_credit_score_cnt,
    ROUND(AVG(is_invalid_credit_score * 100.0), 2) AS invalid_credit_score_pct,
    
    COALESCE(SUM(is_invalid_employment_status), 0) AS invalid_employment_status_cnt,
    ROUND(AVG(is_invalid_employment_status * 100.0), 2) AS invalid_employment_status_pct,
    
    COALESCE(SUM(is_invalid_postal_code), 0) AS invalid_postal_code_cnt,
    ROUND(AVG(is_invalid_postal_code * 100.0), 2) AS invalid_postal_code_pct,
    
    -- 2. Multi-defect Severity & Distribution
    COUNT(CASE WHEN (is_invalid_income + is_invalid_credit_score + is_invalid_employment_status + is_invalid_postal_code) > 0 THEN 1 END) AS total_defective_records_cnt,
    COUNT(CASE WHEN (is_invalid_income + is_invalid_credit_score + is_invalid_employment_status + is_invalid_postal_code) > 1 THEN 1 END) AS multi_defect_records_cnt,
    COALESCE(MAX(is_invalid_income + is_invalid_credit_score + is_invalid_employment_status + is_invalid_postal_code), 0) AS max_defects_per_record,

    -- 3. Batch-level Validity Defect Rate (%)
    ROUND(
        AVG(CASE WHEN (is_invalid_income + is_invalid_credit_score + is_invalid_employment_status + is_invalid_postal_code) > 0 THEN 100.0 ELSE 0.0 END), 
        2
    ) AS batch_defect_rate_pct,

    -- 4. Batch-level SLA Alert Evaluation
    CASE
        WHEN (COALESCE(SUM(is_invalid_income), 0)
            + COALESCE(SUM(is_invalid_credit_score), 0)
            + COALESCE(SUM(is_invalid_employment_status), 0)
            + COALESCE(SUM(is_invalid_postal_code), 0)) > 0
        THEN 'VALIDITY_BREACH_ALERT'
        ELSE 'SLA_CONFORMANT'
    END AS batch_validity_alert_status

FROM evaluated_records;