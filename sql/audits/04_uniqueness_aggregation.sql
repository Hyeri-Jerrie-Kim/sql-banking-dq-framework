/*******************************************************************************
 * SCRIPT NAME:    04_uniqueness_aggregation.sql
 * DOMAIN:         Retail Lending & Risk Analytics
 * TARGET ASSET:   credit_applications (Ingestion Staging Layer)
 * REGULATION:     OSFI Guideline E-21 / BCBS 239 Principle 3 (Data Accuracy)
 *
 * PURPOSE:        Isolate same-day concurrent submission collisions across 
 *                 composite business keys (customer_id, application_date).
 *                 Quantify collision clusters, depth, and surrogate ID ranges
 *                 to diagnose upstream API and mobile ingestion retries.
 *
 * CRITICALITY:    High (Detects ingestion concurrency bugs & duplicate payload drift)
 * SLA / THRESHOLD:Same-day Composite Collisions = 0 across Ingestion Batches
 * CADENCE:        Hourly Micro-batch / Daily Post-Ingestion Trigger
 *
 * OWNER/STEWARD:  Risk Data Governance Team
 *
 * ARCHITECTURE:   
 *   1. composite_collision_clusters: Group by natural composite key, filter HAVING > 1
 *   2. dq_collision_summary        : Aggregate cluster-level metrics for engineering SLA
 *******************************************************************************/
 
 -- Step 1: Group by composite natural keys and isolate collision clusters
 WITH composite_collision_clusters AS(
	 SELECT
		customer_id,
		application_date,
		COUNT(*) AS collision_depth,
		MIN(application_id) AS first_application_id,
		MAX(application_id) AS latest_application_id,
		MAX(application_id) - MIN(application_id) AS id_sequence_gap
	 FROM credit_applications
	 GROUP BY customer_id, application_date
	 HAVING COUNT(*) > 1
 )
 
 -- =============================================================================
-- FINAL STEP: BATCH-LEVEL CONCURRENCY SLA AUDIT SUMMARY
-- =============================================================================
SELECT
	-- 1. Total distinct collision clusters detected
	COUNT(*) AS total_collision_clusters,
    
    -- 2. Total records trapped in collision clusters (Defend against NULL in clean batches)
    COALESCE(SUM(collision_depth), 0) AS total_collided_records,
    
    -- 3. Maximum depth of collision within a single cluster
    COALESCE(MAX(collision_depth), 0) AS max_collision_depth,
    
    -- 4. Automated SLA Audit Evaluation
    CASE
		WHEN COUNT(*) > 0 THEN 'CONCURRENCY_DEFECT_DETECTED'
        ELSE 'CONFORMANT'
	END AS collision_alert_status
FROM composite_collision_clusters;