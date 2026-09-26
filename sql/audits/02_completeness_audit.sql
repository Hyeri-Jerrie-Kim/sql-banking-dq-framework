/*******************************************************************************
 * SCRIPT NAME:    dq_completeness_audit_credit_applications.sql
 * DOMAIN:         Retail Lending & Risk Analytics
 * TARGET ASSET:   credit_applications (Ingestion Raw-to-Staging Layer)
 * REGULATION:     OSFI Guideline E-21 / BCBS 239 Risk Data Aggregation
 *
 * PURPOSE:        Validate completeness across critical credit risk attributes 
 *                 (Income, Employment, Score, Location) prior to scoring model 
 *                 execution to prevent model drift and non-compliance penalties.
 *
 * CRITICALITY:    High (Regulatory Critical Data Element - CDE)
 * SLA / THRESHOLD:Missing Rate <= 0.00% for Income, Score; <= 0.05% for Postal
 * CADENCE:        Daily Batch Pre-processing (Post-Ingestion Trigger)
 *
 * OWNER/STEWARD:  Risk Data Governance Team
 *
 * REVISION HISTORY:
 * 2026-09-25 (v2.0): Refactored aggregation logic to eliminate division-by-zero 
 *                    risks and improve distributed query execution efficiency.
 * 2026-09-24 (v1.0): Initial baseline completeness audit script created.
 *******************************************************************************/

SELECT
    -- =========================================================================
    -- 1. BASE VOLUME METRIC
    -- =========================================================================
    COUNT(*) AS total_records,

    -- =========================================================================
    -- 2. ANNUAL INCOME (DECIMAL: Numeric NULL Audit)
    -- =========================================================================
    COUNT(CASE 
        WHEN annual_income IS NULL 
        THEN 1 
    END) AS missing_income_cnt,
    ROUND(
        AVG(CASE WHEN annual_income IS NULL THEN 100.0 ELSE 0.0 END), 
        2
    ) AS missing_income_pct,

    -- =========================================================================
    -- 3. EMPLOYMENT STATUS (VARCHAR: Semantic Blank & Whitespace Audit)
    -- =========================================================================
    COUNT(CASE 
        WHEN NULLIF(TRIM(employment_status), '') IS NULL 
        THEN 1 
    END) AS missing_emp_cnt,
    ROUND(
        AVG(CASE WHEN NULLIF(TRIM(employment_status), '') IS NULL THEN 100.0 ELSE 0.0 END), 
        2
    ) AS missing_emp_pct,

    -- =========================================================================
    -- 4. CREDIT SCORE (INTEGER: Numeric NULL Audit)
    -- =========================================================================
    COUNT(CASE 
        WHEN credit_score IS NULL 
        THEN 1 
    END) AS missing_score_cnt,
    ROUND(
        AVG(CASE WHEN credit_score IS NULL THEN 100.0 ELSE 0.0 END), 
        2
    ) AS missing_score_pct,

    -- =========================================================================
    -- 5. POSTAL CODE (VARCHAR: Canadian Postal Blank & Whitespace Audit)
    -- =========================================================================
    COUNT(CASE 
        WHEN NULLIF(TRIM(postal_code), '') IS NULL 
        THEN 1 
    END) AS missing_postal_cnt,
    ROUND(
        AVG(CASE WHEN NULLIF(TRIM(postal_code), '') IS NULL THEN 100.0 ELSE 0.0 END), 
        2
    ) AS missing_postal_pct

FROM credit_applications;
