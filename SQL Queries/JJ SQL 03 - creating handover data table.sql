-- =========================================================
-- Export view of the variable-level DQA handoff dataset
-- =========================================================

SELECT
    job_link,
    job_title,
    company,
    job_location,
    search_country,
    first_seen,
    job_skills,
    job_summary
FROM analysis.ba_us_variable_dqa;