/*******************************************************************************
 * SCRIPT NAME:    01_credit_applications_mock.sql
 * DOMAIN:         Retail Lending & Risk Analytics
 * TARGET ASSET:   credit_applications (Ingestion Staging Layer)
 * REGULATION:     OSFI Guideline E-21 / BCBS 239 Risk Data Aggregation
 *
 * PURPOSE:        Synthetic test harness simulating production ingestion feeds.
 *                 Provides a controlled distribution of clean records alongside
 *                 injected data quality defects (Completeness, Uniqueness) for
 *                 deterministic validation of governance audit scripts.
 *
 * TOTAL VOLUME:   13 Records (10 Unique Customer Entities)
 * COMPOSITION:    - Fixture A (Clean Baseline)        : 6 Records (60% of entities)
 *                 - Fixture B (Completeness Defects)  : 4 Records (CDE Nulls/Blanks)
 *                 - Fixture C (Uniqueness Defects)    : 3 Records (Retries/Multi-channel)
 *******************************************************************************/

-- =============================================================================
-- 1. TABLE DDL
-- =============================================================================
DROP TABLE IF EXISTS credit_applications;

CREATE TABLE credit_applications (
    application_id      INT PRIMARY KEY,
    customer_id         INT NOT NULL,
    application_date    DATE NOT NULL,
    annual_income       DECIMAL(12, 2),
    employment_status   VARCHAR(50),
    credit_score        INT,
    postal_code         VARCHAR(10)
);

-- =============================================================================
-- 2. MOCK DATA INJECTION (CONTROLLED DEFECT TAXONOMY)
-- =============================================================================
INSERT INTO credit_applications 
(application_id, customer_id, application_date, annual_income, employment_status, credit_score, postal_code)
VALUES
-- -----------------------------------------------------------------------------
-- [FIXTURE A] Valid Baseline Applications (Control Group: Clean Ingestion)
-- -----------------------------------------------------------------------------
(1001, 20001, '2026-09-01', 95000.00, 'Full-time',     760, 'M5V 2T6'),
(1002, 20002, '2026-09-01', 62000.00, 'Full-time',     690, 'M4B 1B3'),
(1003, 20003, '2026-09-02', 48000.00, 'Part-time',     640, 'M5H 2N2'),
(1004, 20004, '2026-09-02', 110000.00,'Self-employed', 790, 'M2N 6L7'),
(1005, 20005, '2026-09-03', 55000.00, 'Contract',      610, 'M3C 1W5'),
(1006, 20006, '2026-09-03', 82000.00, 'Full-time',     725, 'M6K 3S3'),

-- -----------------------------------------------------------------------------
-- [FIXTURE B] Completeness & Formatting Defects (CDE Missingness Audit)
-- -----------------------------------------------------------------------------
(1007, 20007, '2026-09-04', NULL,     'Full-time',     710, 'M1B 2K9'),  -- CDE Null: Numeric Income
(1008, 20008, '2026-09-04', 73000.00, '',              NULL, 'M4W 1A1'),  -- Semantic Blank Emp & Null Score
(1009, 20009, '2026-09-05', 38000.00, '   ',           540, '   '),      -- Whitespace Only: Emp & Postal
(1010, 20010, '2026-09-05', NULL,     'Part-time',     NULL, NULL),       -- Multi-attribute Regulatory Breach

-- -----------------------------------------------------------------------------
-- [FIXTURE C] Uniqueness & Concurrency Defects (Deduplication Audit)
-- -----------------------------------------------------------------------------
-- Customer 20001: Mobile network timeout auto-retry (Identical payload, later surrogate ID)
(1011, 20001, '2026-09-01', 95000.00, 'Full-time',     760, 'M5V 2T6'),

-- Customer 20001: Subsequent re-application with updated state (True Golden Record)
(1012, 20001, '2026-09-06', 98000.00, 'Full-time',     765, 'M5V 2T6'),

-- Customer 20005: Multi-channel concurrent submission (Branch entry after digital submission)
(1013, 20005, '2026-09-04', 55000.00, 'Contract',      610, 'M3C 1W5');