/*******************************************************************************
 * SCRIPT NAME:    03_uniqueness_dedup.sql
 * DOMAIN:         Retail Lending & Risk Analytics
 * TARGET ASSET:   credit_applications (Ingestion Staging Layer)
 * REGULATION:     OSFI Guideline E-21 / BCBS 239 Principle 3 (Data Accuracy)
 *
 * PURPOSE:        Enterprise deduplication and quarantine pipeline. Establishes 
 *                 deterministic Golden Records for downstream credit scoring models
 *                 while routing duplicates to dead-letter storage for audit trails.
 *
 * CRITICALITY:    High (Prevents duplicate credit limits and inaccurate model exposure)
 * SLA / THRESHOLD:Duplicate Record Rate <= 0.00% across Ingestion Batches
 * CADENCE:        Hourly Micro-batch / Daily Ingestion Trigger
 *
 * OWNER/STEWARD:  Risk Data Governance Team
 *
 * ARCHITECTURE:
 *   1. ranked_staging     : Preserve all CDE attributes and compute deterministic rank.
 *   2. governance_routed  : Tag records as GOLDEN (for scoring) or QUARANTINE (for audit).
 *   3. dq_metric_summary  : Single-row KPI report evaluating batch-level SLA breach.
 *******************************************************************************/

-- Step 1: Ingest full attribute schema and compute deterministic ranking per natural key
WITH ranked_staging AS (
    SELECT
        application_id,
        customer_id,
        application_date,
        annual_income,
        employment_status,
        credit_score,
        postal_code,
        -- Tie-breaker: Latest submission date takes precedence; highest ID resolves concurrent collisions
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY application_date DESC, application_id DESC
        ) AS rank_within_entity
    FROM credit_applications
),

-- Step 2: Apply enterprise data governance routing tags
governance_routed AS (
    SELECT
        application_id,
        customer_id,
        application_date,
        annual_income,
        employment_status,
        credit_score,
        postal_code,
        rank_within_entity,
        CASE 
            WHEN rank_within_entity = 1 THEN 'GOLDEN'
            ELSE 'QUARANTINE'
        END AS dedup_status,
        CASE 
            WHEN rank_within_entity > 1 THEN 'DUPLICATE_ENTITY_SUBMISSION'
            ELSE NULL 
        END AS quarantine_reason
    FROM ranked_staging
)

-- =============================================================================
-- FINAL STEP: BATCH-LEVEL DATA QUALITY AUDIT SUMMARY (SLA MONITORING)
-- (Downstream consumers can query governance_routed directly for Golden/Quarantine splits)
-- =============================================================================
SELECT
    -- 1. Batch Volume Metrics
    COUNT(*) AS total_records_evaluated,
    COUNT(DISTINCT customer_id) AS total_unique_entities,
    
    -- 2. Pipeline Routing Volumes
    COUNT(CASE WHEN dedup_status = 'GOLDEN' THEN 1 END) AS golden_records_passed,
    COUNT(CASE WHEN dedup_status = 'QUARANTINE' THEN 1 END) AS quarantined_duplicates_cnt,
    
    -- 3. Governance SLA KPI (with Float Promotion & Zero-division Protection)
    ROUND(
        AVG(CASE WHEN dedup_status = 'QUARANTINE' THEN 100.0 ELSE 0.0 END), 
        2
    ) AS duplicate_record_rate_pct,

    -- 4. Automated SLA Audit Breached Evaluation
    CASE 
        WHEN COUNT(CASE WHEN dedup_status = 'QUARANTINE' THEN 1 END) > 0 
        THEN 'SLA_BREACH_ALERT' 
        ELSE 'SLA_CONFORMANT' 
    END AS pipeline_alert_status

FROM governance_routed;