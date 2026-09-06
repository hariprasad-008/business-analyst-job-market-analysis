/*
SQL 01 - Raw Data Load

Related documentation:
Documentation 00 - Project Log

Purpose:
Creates raw tables and loads the three original Kaggle CSV files
without performing data cleaning or transformation.
*/

USE [LinkedIn_BI_Assignment];
GO

-- Appropriate for this local analytical project.
-- SIMPLE recovery helps prevent unnecessary transaction-log growth
-- during large bulk-load operations.
ALTER DATABASE [LinkedIn_BI_Assignment]
SET RECOVERY SIMPLE;
GO


-- Remove these tables only if this raw-loading script is being rerun.
DROP TABLE IF EXISTS raw.job_skills;
DROP TABLE IF EXISTS raw.job_summary;
DROP TABLE IF EXISTS raw.linkedin_job_postings;
GO


CREATE TABLE raw.linkedin_job_postings
(
    job_link             NVARCHAR(MAX),
    last_processed_time  NVARCHAR(MAX),
    got_summary          NVARCHAR(MAX),
    got_ner              NVARCHAR(MAX),
    is_being_worked      NVARCHAR(MAX),
    job_title            NVARCHAR(MAX),
    company              NVARCHAR(MAX),
    job_location         NVARCHAR(MAX),
    first_seen           NVARCHAR(MAX),
    search_city          NVARCHAR(MAX),
    search_country       NVARCHAR(MAX),
    search_position      NVARCHAR(MAX),
    job_level            NVARCHAR(MAX),
    job_type             NVARCHAR(MAX)
);
GO


CREATE TABLE raw.job_skills
(
    job_link    NVARCHAR(MAX),
    job_skills  NVARCHAR(MAX)
);
GO


CREATE TABLE raw.job_summary
(
    job_link     NVARCHAR(MAX),
    job_summary  NVARCHAR(MAX)
);
GO

-- Check whether SQL Server can access the three source CSV files.

EXEC master.dbo.xp_fileexist
    'C:\BI assigment\RAW\job_skills.csv';

EXEC master.dbo.xp_fileexist
    'C:\BI assigment\RAW\linkedin_job_postings.csv';

EXEC master.dbo.xp_fileexist
    'C:\BI assigment\RAW\job_summary.csv';

    TRUNCATE TABLE raw.job_skills;
GO

-- Load job_skills.csv into the raw schema.
-- Explicit terminators are specified because the source CSV
-- uses comma-separated fields and line-feed row endings.

BULK INSERT raw.job_skills
FROM 'C:\BI assigment\RAW\job_skills.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

SELECT COUNT(*) AS LoadedRows
FROM raw.job_skills;

SELECT TOP (10)
    job_link,
    job_skills
FROM raw.job_skills;


-- =========================================================
-- Load linkedin_job_postings.csv
-- =========================================================

-- Ensures the table is empty if this section needs to be rerun.
TRUNCATE TABLE raw.linkedin_job_postings;
GO

BULK INSERT raw.linkedin_job_postings
FROM 'C:\BI assigment\RAW\linkedin_job_postings.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

SELECT COUNT(*) AS LoadedRows
FROM raw.linkedin_job_postings;

SELECT TOP (10)
    job_link,
    job_title,
    company,
    job_location,
    search_city,
    search_country,
    job_level,
    job_type
FROM raw.linkedin_job_postings;

-- =========================================================
-- Load job_summary.csv
-- =========================================================

-- Ensures the table is empty if this section needs to be rerun.
TRUNCATE TABLE raw.job_summary;
GO

BULK INSERT raw.job_summary
FROM 'C:\BI assigment\RAW\job_summary.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

SELECT COUNT(*) AS LoadedRows
FROM raw.job_summary;

SELECT TOP (10)
    job_link,
    LEFT(job_summary, 500) AS job_summary_preview
FROM raw.job_summary;