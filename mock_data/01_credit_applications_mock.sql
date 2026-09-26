/*******************************************************************************
 * SCRIPT NAME:    01_credit_applications_mock.sql
 * PURPOSE:        Mock DDL & Test Dataset for Retail Lending DQ Audits
 * TARGET ASSET:   credit_applications (Staging Layer)
 * PROFILE:        10 Records (6 Valid, 4 Controlled DQ Defects)
 *******************************************************************************/

-- 1. Table DDL
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

-- 2. Mock Data Injection (Controlled Distribution)
INSERT INTO credit_applications 
(application_id, customer_id, application_date, annual_income, employment_status, credit_score, postal_code)
VALUES
-- [CONTROL GROUP: 6 Valid Baseline Records]
(1001, 20001, '2026-09-01', 95000.00, 'Full-time',  760, 'M5V 2T6'),
(1002, 20002, '2026-09-01', 62000.00, 'Full-time',  690, 'M4B 1B3'),
(1003, 20003, '2026-09-02', 48000.00, 'Part-time',  640, 'M5H 2N2'),
(1004, 20004, '2026-09-02', 110000.00,'Self-employed', 790, 'M2N 6L7'),
(1005, 20005, '2026-09-03', 55000.00, 'Contract',   610, 'M3C 1W5'),
(1006, 20006, '2026-09-03', 82000.00, 'Full-time',  725, 'M6K 3S3'),

-- [TEST DEFECT GROUP: 4 Controlled Edge Cases]
(1007, 20007, '2026-09-04', NULL,     'Full-time',  710, 'M1B 2K9'),  -- Defect 1: Numeric NULL (Income)
(1008, 20008, '2026-09-04', 73000.00, '',           NULL, 'M4W 1A1'),  -- Defect 2: Empty String (Emp) & NULL (Score)
(1009, 20009, '2026-09-05', 38000.00, '   ',        540, '   '),      -- Defect 3: Whitespace Only (Emp & Postal)
(1010, 20010, '2026-09-05', NULL,     'Part-time',  NULL, NULL);       -- Defect 4: Multi-column NULL (Income, Score, Postal)
