/*
SQL 02 - Initial Exploration

Related documentation:
Documentation 00 - Project Log

Purpose:
Develop an initial understanding of the supplied datasets before
finalising the Iteration 1 analytical scope.

This stage explores the data but does not clean or transform it.
*/

USE [LinkedIn_BI_Assignment];
GO

-- =========================================================
-- 1. Basic table size and job_link coverage
-- =========================================================

SELECT
    'linkedin_job_postings' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT CAST(job_link AS NVARCHAR(2000))) AS distinct_job_links
FROM raw.linkedin_job_postings

UNION ALL

SELECT
    'job_skills',
    COUNT(*),
    COUNT(DISTINCT CAST(job_link AS NVARCHAR(2000)))
FROM raw.job_skills

UNION ALL

SELECT
    'job_summary',
    COUNT(*),
    COUNT(DISTINCT CAST(job_link AS NVARCHAR(2000)))
FROM raw.job_summary;

-- =========================================================
-- 2. Cross-table job_link coverage
-- =========================================================

SELECT
    COUNT(*) AS total_postings,

    SUM(CASE
        WHEN s.job_link IS NOT NULL THEN 1
        ELSE 0
    END) AS postings_with_skills,

    SUM(CASE
        WHEN s.job_link IS NULL THEN 1
        ELSE 0
    END) AS postings_without_skills,

    SUM(CASE
        WHEN js.job_link IS NOT NULL THEN 1
        ELSE 0
    END) AS postings_with_summary,

    SUM(CASE
        WHEN js.job_link IS NULL THEN 1
        ELSE 0
    END) AS postings_without_summary,

    SUM(CASE
        WHEN s.job_link IS NOT NULL
         AND js.job_link IS NOT NULL THEN 1
        ELSE 0
    END) AS postings_with_both

FROM raw.linkedin_job_postings p

LEFT JOIN raw.job_skills s
    ON p.job_link = s.job_link

LEFT JOIN raw.job_summary js
    ON p.job_link = js.job_link;


    -- =========================================================
-- 3. Explore Business Analyst-related terms in job_skills
-- =========================================================

SELECT TOP (100)
    job_link,
    job_skills
FROM raw.job_skills
WHERE LOWER(job_skills) LIKE '%business analy%';


-- =========================================================
-- 4. Quantify Business Analyst-related skill terminology
-- =========================================================

SELECT
    LOWER(TRIM(value)) AS skill_term,
    COUNT(DISTINCT CAST(job_link AS NVARCHAR(2000))) AS job_count
FROM raw.job_skills
CROSS APPLY STRING_SPLIT(job_skills, ',')
WHERE LOWER(TRIM(value)) LIKE '%business analy%'
GROUP BY LOWER(TRIM(value))
ORDER BY job_count DESC;

-- =========================================================
-- 5. Compare possible Business Analyst population definitions
-- =========================================================

WITH skills_long AS
(
    SELECT
        job_link,
        LOWER(TRIM(value)) AS skill_term
    FROM raw.job_skills
    CROSS APPLY STRING_SPLIT(job_skills, ',')
)

SELECT
    'Exact Business Analysis only' AS definition,
    COUNT(DISTINCT CAST(job_link AS NVARCHAR(2000))) AS job_count
FROM skills_long
WHERE skill_term = 'business analysis'

UNION ALL

SELECT
    'Business Analysis or Business Analyst exact',
    COUNT(DISTINCT CAST(job_link AS NVARCHAR(2000)))
FROM skills_long
WHERE skill_term IN ('business analysis', 'business analyst')

UNION ALL

SELECT
    'Broad BA-related terms excluding Business Analytics',
    COUNT(DISTINCT CAST(job_link AS NVARCHAR(2000)))
FROM skills_long
WHERE
    (
        skill_term LIKE '%business analysis%'
        OR skill_term LIKE '%business analyst%'
    )
    AND skill_term NOT LIKE '%business analytics%';

    -- =========================================================
-- 6. Inspect jobs captured only by the broad BA definition
-- =========================================================


DROP TABLE IF EXISTS #ba_terms;

SELECT
    js.job_link,
    LOWER(TRIM(s.value)) AS skill_term
INTO #ba_terms
FROM raw.job_skills js
CROSS APPLY STRING_SPLIT(js.job_skills, ',') s
WHERE
    LOWER(js.job_skills) LIKE '%business analysis%'
    OR LOWER(js.job_skills) LIKE '%business analyst%';


SELECT TOP (100)
    b.job_link,
    b.skill_term
FROM #ba_terms b
WHERE
    (
        b.skill_term LIKE '%business analysis%'
        OR b.skill_term LIKE '%business analyst%'
    )
    AND b.skill_term NOT LIKE '%business analytics%'
    AND NOT EXISTS
    (
        SELECT 1
        FROM #ba_terms e
        WHERE e.job_link = b.job_link
          AND e.skill_term IN ('business analysis', 'business analyst')
    )
ORDER BY b.skill_term;

-- =========================================================
-- Query 7. Identify Business Analyst-titled jobs missed
--          by the original exact skill-based definition
-- =========================================================

-- Recreate the original skill-confirmed BA population
DROP TABLE IF EXISTS #skill_confirmed_ba;

SELECT DISTINCT
    js.job_link
INTO #skill_confirmed_ba
FROM raw.job_skills js
CROSS APPLY STRING_SPLIT(js.job_skills, ',') s
WHERE LOWER(TRIM(s.value))
      IN ('business analysis', 'business analyst');


-- Compare Business Analyst-titled jobs against
-- the original skill-confirmed population
SELECT
    COUNT(*) AS total_business_analyst_titled_jobs,

    SUM(
        CASE
            WHEN s.job_link IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS already_skill_confirmed,

    SUM(
        CASE
            WHEN s.job_link IS NULL THEN 1
            ELSE 0
        END
    ) AS missed_by_skill_rule

FROM raw.linkedin_job_postings p

LEFT JOIN #skill_confirmed_ba s
    ON p.job_link = s.job_link

WHERE LOWER(p.job_title) LIKE '%business analyst%'
  AND LOWER(p.job_title) NOT LIKE '%business analytics%';

  -- =========================================================
-- Query 8. Inspect job-title patterns among Business
--          Analyst-titled jobs missed by the skill rule
-- =========================================================

SELECT TOP (100)
    TRIM(p.job_title) AS job_title,
    COUNT(*) AS job_count
FROM raw.linkedin_job_postings p

LEFT JOIN #skill_confirmed_ba s
    ON p.job_link = s.job_link

WHERE LOWER(p.job_title) LIKE '%business analyst%'
  AND LOWER(p.job_title) NOT LIKE '%business analytics%'
  AND s.job_link IS NULL

GROUP BY TRIM(p.job_title)
ORDER BY job_count DESC;

-- =========================================================
-- Query 9. Inspect Business...Analyst titles not captured
--          by the explicit "Business Analyst" title rule
-- =========================================================

SELECT TOP (100)
    TRIM(p.job_title) AS job_title,
    COUNT(*) AS job_count
FROM raw.linkedin_job_postings p

LEFT JOIN #skill_confirmed_ba s
    ON p.job_link = s.job_link

WHERE LOWER(p.job_title) LIKE '%business%analyst%'
  AND LOWER(p.job_title) NOT LIKE '%business analyst%'
  AND LOWER(p.job_title) NOT LIKE '%business analytics%'
  AND s.job_link IS NULL

GROUP BY TRIM(p.job_title)
ORDER BY job_count DESC;

-- =========================================================
-- Query 10. Quantify candidate BA-related title families
--          missed by previous inclusion rules
-- =========================================================

SELECT
    CASE
        WHEN LOWER(p.job_title) LIKE '%business systems analyst%'
          OR LOWER(p.job_title) LIKE '%business system analyst%'
            THEN 'Business System(s) Analyst'

        WHEN LOWER(p.job_title) LIKE '%business process analyst%'
            THEN 'Business Process Analyst'
    END AS candidate_title_family,

    COUNT(*) AS job_count

FROM raw.linkedin_job_postings p

LEFT JOIN #skill_confirmed_ba s
    ON p.job_link = s.job_link

WHERE s.job_link IS NULL

  -- Exclude jobs already captured by explicit Business Analyst title
  AND LOWER(p.job_title) NOT LIKE '%business analyst%'

  AND
  (
       LOWER(p.job_title) LIKE '%business systems analyst%'
    OR LOWER(p.job_title) LIKE '%business system analyst%'
    OR LOWER(p.job_title) LIKE '%business process analyst%'
  )

GROUP BY
    CASE
        WHEN LOWER(p.job_title) LIKE '%business systems analyst%'
          OR LOWER(p.job_title) LIKE '%business system analyst%'
            THEN 'Business System(s) Analyst'

        WHEN LOWER(p.job_title) LIKE '%business process analyst%'
            THEN 'Business Process Analyst'
    END

ORDER BY job_count DESC;

-- =========================================================
-- Query 11. Inspect skills and job descriptions for
--          candidate BA-related title families
-- =========================================================

WITH candidate_jobs AS
(
    SELECT
        p.job_link,
        p.job_title,

        CASE
            WHEN LOWER(p.job_title) LIKE '%business systems analyst%'
              OR LOWER(p.job_title) LIKE '%business system analyst%'
                THEN 'Business System(s) Analyst'

            WHEN LOWER(p.job_title) LIKE '%business process analyst%'
                THEN 'Business Process Analyst'
        END AS candidate_title_family,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                CASE
                    WHEN LOWER(p.job_title) LIKE '%business systems analyst%'
                      OR LOWER(p.job_title) LIKE '%business system analyst%'
                        THEN 'Business System(s) Analyst'

                    WHEN LOWER(p.job_title) LIKE '%business process analyst%'
                        THEN 'Business Process Analyst'
                END

            ORDER BY NEWID()
        ) AS sample_number

    FROM raw.linkedin_job_postings p

    LEFT JOIN #skill_confirmed_ba s
        ON p.job_link = s.job_link

    WHERE s.job_link IS NULL

      AND LOWER(p.job_title) NOT LIKE '%business analyst%'

      AND
      (
           LOWER(p.job_title) LIKE '%business systems analyst%'
        OR LOWER(p.job_title) LIKE '%business system analyst%'
        OR LOWER(p.job_title) LIKE '%business process analyst%'
      )
)

SELECT
    c.candidate_title_family,
    c.job_title,
    js.job_skills,
    LEFT(j.job_summary, 700) AS job_summary_preview

FROM candidate_jobs c

LEFT JOIN raw.job_skills js
    ON c.job_link = js.job_link

LEFT JOIN raw.job_summary j
    ON c.job_link = j.job_link

WHERE c.sample_number <= 15

ORDER BY
    c.candidate_title_family,
    c.sample_number;

    -- =========================================================
-- Query 12. Quantify BA-related activity evidence within
--          candidate title families
-- =========================================================

WITH candidate_jobs AS
(
    SELECT
        p.job_link,

        CASE
            WHEN LOWER(p.job_title) LIKE '%business systems analyst%'
              OR LOWER(p.job_title) LIKE '%business system analyst%'
                THEN 'Business System(s) Analyst'

            WHEN LOWER(p.job_title) LIKE '%business process analyst%'
                THEN 'Business Process Analyst'
        END AS candidate_title_family

    FROM raw.linkedin_job_postings p

    LEFT JOIN #skill_confirmed_ba s
        ON p.job_link = s.job_link

    WHERE s.job_link IS NULL
      AND LOWER(p.job_title) NOT LIKE '%business analyst%'

      AND
      (
           LOWER(p.job_title) LIKE '%business systems analyst%'
        OR LOWER(p.job_title) LIKE '%business system analyst%'
        OR LOWER(p.job_title) LIKE '%business process analyst%'
      )
),

evidence AS
(
    SELECT
        c.job_link,
        c.candidate_title_family,

        CASE
            WHEN LOWER(COALESCE(js.job_skills, '')) LIKE '%requirements%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%stakeholder%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%process analysis%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%process improvement%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%process mapping%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%user stories%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%gap analysis%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%functional requirements%'

              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%requirements%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%stakeholder%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%process analysis%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%process improvement%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%process mapping%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%user stories%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%gap analysis%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%functional requirements%'

            THEN 1
            ELSE 0
        END AS has_ba_activity_evidence

    FROM candidate_jobs c

    LEFT JOIN raw.job_skills js
        ON c.job_link = js.job_link

    LEFT JOIN raw.job_summary j
        ON c.job_link = j.job_link
)

SELECT
    candidate_title_family,
    COUNT(*) AS total_candidate_jobs,

    SUM(has_ba_activity_evidence) AS jobs_with_ba_evidence,

    COUNT(*) - SUM(has_ba_activity_evidence) AS jobs_without_ba_evidence,

    CAST(
        100.0 * SUM(has_ba_activity_evidence) / COUNT(*)
        AS DECIMAL(5,2)
    ) AS percentage_with_ba_evidence

FROM evidence

GROUP BY candidate_title_family

ORDER BY candidate_title_family;

-- =========================================================
-- Query 13. Quantify standalone BA-acronym job titles
--          missed by the existing inclusion rules
-- =========================================================

WITH normalized_titles AS
(
    SELECT
        p.job_link,
        p.job_title,

        LOWER(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
                p.job_title,
                '-', ' '),
                '/', ' '),
                '(', ' '),
                ')', ' '),
                ',', ' '),
                '.', ' ')
        ) AS normalized_title

    FROM raw.linkedin_job_postings p
)

SELECT
    COUNT(*) AS ba_acronym_candidate_jobs

FROM normalized_titles p

LEFT JOIN #skill_confirmed_ba s
    ON p.job_link = s.job_link

WHERE
    -- Standalone BA token
    ' ' + p.normalized_title + ' ' LIKE '% ba %'

    -- Not already captured by exact BA skill
    AND s.job_link IS NULL

    -- Not already captured by explicit Business Analyst title
    AND LOWER(p.job_title) NOT LIKE '%business analyst%'

    -- Not the additional title families we have just accepted
    AND LOWER(p.job_title) NOT LIKE '%business systems analyst%'
    AND LOWER(p.job_title) NOT LIKE '%business system analyst%'
    AND LOWER(p.job_title) NOT LIKE '%business process analyst%';

    -- =========================================================
-- Query 14. Inspect standalone BA-acronym job-title patterns
-- =========================================================

WITH normalized_titles AS
(
    SELECT
        p.job_link,
        p.job_title,

        LOWER(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
                p.job_title,
                '-', ' '),
                '/', ' '),
                '(', ' '),
                ')', ' '),
                ',', ' '),
                '.', ' ')
        ) AS normalized_title

    FROM raw.linkedin_job_postings p
)

SELECT TOP (100)
    TRIM(p.job_title) AS job_title,
    COUNT(*) AS job_count

FROM normalized_titles p

LEFT JOIN #skill_confirmed_ba s
    ON p.job_link = s.job_link

WHERE
    ' ' + p.normalized_title + ' ' LIKE '% ba %'

    AND s.job_link IS NULL

    AND LOWER(p.job_title) NOT LIKE '%business analyst%'

    AND LOWER(p.job_title) NOT LIKE '%business systems analyst%'
    AND LOWER(p.job_title) NOT LIKE '%business system analyst%'
    AND LOWER(p.job_title) NOT LIKE '%business process analyst%'

GROUP BY TRIM(p.job_title)

ORDER BY job_count DESC;

-- =========================================================
-- Query 15. Quantify BA-related activity evidence among
--          standalone BA-acronym title candidates
-- =========================================================

WITH normalized_titles AS
(
    SELECT
        p.job_link,
        p.job_title,

        LOWER(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
            REPLACE(
                p.job_title,
                '-', ' '),
                '/', ' '),
                '(', ' '),
                ')', ' '),
                ',', ' '),
                '.', ' ')
        ) AS normalized_title

    FROM raw.linkedin_job_postings p
),

ba_acronym_candidates AS
(
    SELECT
        p.job_link,
        p.job_title

    FROM normalized_titles p

    LEFT JOIN #skill_confirmed_ba s
        ON p.job_link = s.job_link

    WHERE
        ' ' + p.normalized_title + ' ' LIKE '% ba %'

        AND s.job_link IS NULL

        AND LOWER(p.job_title) NOT LIKE '%business analyst%'

        AND LOWER(p.job_title) NOT LIKE '%business systems analyst%'
        AND LOWER(p.job_title) NOT LIKE '%business system analyst%'
        AND LOWER(p.job_title) NOT LIKE '%business process analyst%'
),

evidence AS
(
    SELECT
        c.job_link,
        c.job_title,

        CASE
            WHEN LOWER(COALESCE(js.job_skills, '')) LIKE '%requirements%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%stakeholder%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%process analysis%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%process improvement%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%process mapping%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%user stories%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%gap analysis%'
              OR LOWER(COALESCE(js.job_skills, '')) LIKE '%functional requirements%'

              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%requirements%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%stakeholder%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%process analysis%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%process improvement%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%process mapping%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%user stories%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%gap analysis%'
              OR LOWER(COALESCE(j.job_summary, '')) LIKE '%functional requirements%'

            THEN 1
            ELSE 0
        END AS has_ba_activity_evidence

    FROM ba_acronym_candidates c

    LEFT JOIN raw.job_skills js
        ON c.job_link = js.job_link

    LEFT JOIN raw.job_summary j
        ON c.job_link = j.job_link
)

SELECT
    COUNT(*) AS total_ba_acronym_candidates,
    SUM(has_ba_activity_evidence) AS jobs_with_ba_evidence,
    COUNT(*) - SUM(has_ba_activity_evidence) AS jobs_without_ba_evidence,

    CAST(
        100.0 * SUM(has_ba_activity_evidence) / COUNT(*)
        AS DECIMAL(5,2)
    ) AS percentage_with_ba_evidence

FROM evidence;

-- =========================================================
-- Query 16. Build and verify the refined BA population
-- =========================================================

DROP TABLE IF EXISTS #refined_ba_jobs;

WITH explicit_ba_titles AS
(
    SELECT DISTINCT
        p.job_link
    FROM raw.linkedin_job_postings p
    WHERE LOWER(p.job_title) LIKE '%business analyst%'
      AND LOWER(p.job_title) NOT LIKE '%business analytics%'
),

validated_related_titles AS
(
    SELECT DISTINCT
        p.job_link
    FROM raw.linkedin_job_postings p
    WHERE
           LOWER(p.job_title) LIKE '%business systems analyst%'
        OR LOWER(p.job_title) LIKE '%business system analyst%'
        OR LOWER(p.job_title) LIKE '%business process analyst%'
)

SELECT job_link
INTO #refined_ba_jobs
FROM
(
    -- Original exact skill-confirmed population
    SELECT job_link
    FROM #skill_confirmed_ba

    UNION

    -- Explicit Business Analyst titles
    SELECT job_link
    FROM explicit_ba_titles

    UNION

    -- Validated related title families
    SELECT job_link
    FROM validated_related_titles
) refined;


-- Verify final refined population size
SELECT
    COUNT(*) AS refined_ba_population
FROM #refined_ba_jobs;

-- =========================================================
-- Query 17. Reassess collection-country distribution
--           using the refined BA population
-- =========================================================

SELECT
    p.search_country,
    COUNT(*) AS job_count,

    CAST(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS percentage_of_refined_ba_jobs

FROM #refined_ba_jobs r

JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link

GROUP BY p.search_country

ORDER BY job_count DESC;

-- =========================================================
-- Query 18. Save the refined BA population
--           as a permanent analysis table
-- =========================================================

DROP TABLE IF EXISTS analysis.refined_ba_jobs;

SELECT
    r.job_link
INTO analysis.refined_ba_jobs
FROM #refined_ba_jobs r;


-- Verify saved population
SELECT
    COUNT(*) AS refined_ba_population
FROM analysis.refined_ba_jobs;

-- =========================================================
-- Query 19. Create the refined U.S. BA analytical subset
-- =========================================================

DROP TABLE IF EXISTS analysis.refined_ba_us_jobs;

SELECT
    r.job_link
INTO analysis.refined_ba_us_jobs
FROM analysis.refined_ba_jobs r

JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link

WHERE p.search_country = 'United States';


-- Verify U.S. analytical population
SELECT
    COUNT(*) AS refined_us_ba_population
FROM analysis.refined_ba_us_jobs;

-- =========================================================
-- Query 20. Assess advertised job-location coverage
--           within the refined U.S. BA population
-- =========================================================

SELECT
    COUNT(*) AS total_us_ba_jobs,

    SUM(
        CASE
            WHEN p.job_location IS NULL
              OR LTRIM(RTRIM(p.job_location)) = ''
            THEN 1
            ELSE 0
        END
    ) AS missing_job_location,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN p.job_location IS NULL
                  OR LTRIM(RTRIM(p.job_location)) = ''
                THEN 1
                ELSE 0
            END
        ) / COUNT(*)
        AS DECIMAL(5,2)
    ) AS percentage_missing,

    COUNT(DISTINCT p.job_location) AS distinct_job_locations

FROM analysis.refined_ba_us_jobs r

JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link;

  -- =========================================================
-- Query 21. Assess overall dataset temporal coverage
-- =========================================================

WITH parsed_dates AS
(
    SELECT
        TRY_CONVERT(DATE, first_seen) AS first_seen_date
    FROM raw.linkedin_job_postings
)

SELECT
    COUNT(*) AS total_job_postings,

    COUNT(first_seen_date) AS postings_with_valid_first_seen_date,

    COUNT(*) - COUNT(first_seen_date) AS postings_without_valid_first_seen_date,

    MIN(first_seen_date) AS earliest_first_seen_date,

    MAX(first_seen_date) AS latest_first_seen_date,

    COUNT(DISTINCT first_seen_date) AS distinct_collection_dates

FROM parsed_dates;

-- =========================================================
-- Query 22. Assess job-type distribution
--           within refined U.S. BA population
-- =========================================================

SELECT
    p.job_type,
    COUNT(*) AS job_count,

    CAST(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS percentage_of_us_ba_jobs

FROM analysis.refined_ba_us_jobs r

JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link

GROUP BY p.job_type

ORDER BY job_count DESC;

-- =========================================================
-- Query 23. Assess job-level distribution
--           within refined U.S. BA population
-- =========================================================

SELECT
    p.job_level,
    COUNT(*) AS job_count,

    CAST(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS percentage_of_us_ba_jobs

FROM analysis.refined_ba_us_jobs r

JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link

GROUP BY p.job_level

ORDER BY job_count DESC;

-- =========================================================
-- Query 24. Assess employer distribution
--           within refined U.S. BA population
-- =========================================================

WITH company_counts AS
(
    SELECT
        p.company,
        COUNT(*) AS job_count
    FROM analysis.refined_ba_us_jobs r

    JOIN raw.linkedin_job_postings p
        ON r.job_link = p.job_link

    GROUP BY p.company
)

SELECT TOP (30)
    company,
    job_count,

    CAST(
        100.0 * job_count /
        SUM(job_count) OVER ()
        AS DECIMAL(5,2)
    ) AS percentage_of_us_ba_jobs,

    COUNT(*) OVER () AS distinct_companies

FROM company_counts

ORDER BY job_count DESC;

-- =========================================================
-- Query 25. Explore complementary skills and requirements
--           within refined U.S. BA population
-- =========================================================

WITH split_skills AS
(
    SELECT
        r.job_link,
        LTRIM(RTRIM(s.value)) AS skill
    FROM analysis.refined_ba_us_jobs r

    JOIN raw.job_skills js
        ON r.job_link = js.job_link

    CROSS APPLY STRING_SPLIT(js.job_skills, ',') s

    WHERE LTRIM(RTRIM(s.value)) <> ''
)

SELECT TOP (30)
    skill,
    COUNT(DISTINCT job_link) AS job_count,

    CAST(
        100.0 * COUNT(DISTINCT job_link) / 8610
        AS DECIMAL(5,2)
    ) AS percentage_of_us_ba_jobs

FROM split_skills

WHERE LOWER(skill) NOT IN
(
    'business analysis',
    'business analyst'
)

GROUP BY skill

ORDER BY job_count DESC;

-- =========================================================
-- Query 26. Assess job-title fragmentation
--           within refined U.S. BA population
-- =========================================================

WITH title_counts AS
(
    SELECT
        LTRIM(RTRIM(p.job_title)) AS job_title,
        COUNT(*) AS job_count
    FROM analysis.refined_ba_us_jobs r

    JOIN raw.linkedin_job_postings p
        ON r.job_link = p.job_link

    GROUP BY LTRIM(RTRIM(p.job_title))
)

SELECT
    SUM(job_count) AS total_us_ba_jobs,

    COUNT(*) AS distinct_job_titles,

    SUM(
        CASE
            WHEN job_count = 1 THEN 1
            ELSE 0
        END
    ) AS titles_occurring_once,

    SUM(
        CASE
            WHEN job_count > 1 THEN 1
            ELSE 0
        END
    ) AS titles_occurring_more_than_once,

    SUM(
        CASE
            WHEN job_count = 1 THEN job_count
            ELSE 0
        END
    ) AS jobs_with_one_off_titles,

    CAST(
        100.0 *
        SUM(CASE WHEN job_count = 1 THEN 1 ELSE 0 END)
        / COUNT(*)
        AS DECIMAL(5,2)
    ) AS percentage_of_titles_occurring_once

FROM title_counts;

-- =========================================================
-- Query 27. Inspect most frequent job titles
--           within refined U.S. BA population
-- =========================================================

SELECT TOP (30)
    LTRIM(RTRIM(p.job_title)) AS job_title,
    COUNT(*) AS job_count,

    CAST(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS percentage_of_us_ba_jobs

FROM analysis.refined_ba_us_jobs r

JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link

GROUP BY LTRIM(RTRIM(p.job_title))

ORDER BY job_count DESC;

-- =========================================================
-- Query 28. Assess potential repeated job advertisements
--           across the overall dataset
-- =========================================================

WITH posting_combinations AS
(
    SELECT
        LOWER(LTRIM(RTRIM(job_title))) AS job_title,
        LOWER(LTRIM(RTRIM(company))) AS company,
        LOWER(LTRIM(RTRIM(job_location))) AS job_location,
        COUNT(*) AS occurrence_count
    FROM raw.linkedin_job_postings
    GROUP BY
        LOWER(LTRIM(RTRIM(job_title))),
        LOWER(LTRIM(RTRIM(company))),
        LOWER(LTRIM(RTRIM(job_location)))
)

SELECT
    (SELECT COUNT(*)
     FROM raw.linkedin_job_postings) AS total_job_postings,

    COUNT(*) AS distinct_title_company_location_combinations,

    SUM(
        CASE
            WHEN occurrence_count > 1 THEN 1
            ELSE 0
        END
    ) AS repeated_combinations,

    SUM(
        CASE
            WHEN occurrence_count > 1 THEN occurrence_count
            ELSE 0
        END
    ) AS jobs_in_repeated_combinations,

    SUM(
        CASE
            WHEN occurrence_count > 1 THEN occurrence_count - 1
            ELSE 0
        END
    ) AS potential_excess_records,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN occurrence_count > 1 THEN occurrence_count
                ELSE 0
            END
        )
        /
        (SELECT COUNT(*) FROM raw.linkedin_job_postings)
        AS DECIMAL(5,2)
    ) AS percentage_jobs_in_repeated_combinations

FROM posting_combinations;

-- =========================================================
-- Query 29. Sensitivity check for potential repeated postings
-- =========================================================

DROP TABLE IF EXISTS #ba_us_sensitivity;

WITH ranked_jobs AS
(
    SELECT
        r.job_link,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                LOWER(LTRIM(RTRIM(p.job_title))),
                LOWER(LTRIM(RTRIM(p.company))),
                LOWER(LTRIM(RTRIM(p.job_location)))
            ORDER BY r.job_link
        ) AS duplicate_rank

    FROM analysis.refined_ba_us_jobs r

    JOIN raw.linkedin_job_postings p
        ON r.job_link = p.job_link
)

SELECT
    job_link
INTO #ba_us_sensitivity

FROM ranked_jobs

WHERE duplicate_rank = 1;


SELECT
    (SELECT COUNT(*)
     FROM analysis.refined_ba_us_jobs) AS original_population,

    (SELECT COUNT(*)
     FROM #ba_us_sensitivity) AS sensitivity_population,

    (SELECT COUNT(*)
     FROM analysis.refined_ba_us_jobs)
    -
    (SELECT COUNT(*)
     FROM #ba_us_sensitivity) AS potential_repeated_records_removed,

    CAST(
        100.0 *
        (
            (SELECT COUNT(*) FROM analysis.refined_ba_us_jobs)
            -
            (SELECT COUNT(*) FROM #ba_us_sensitivity)
        )
        /
        (SELECT COUNT(*) FROM analysis.refined_ba_us_jobs)

        AS DECIMAL(5,2)
    ) AS percentage_removed;


    -- =========================================================
-- Query 30. Compare key analytical patterns before and
--           after removing potential repeated postings
-- =========================================================

-- ---------------------------------------------------------
-- A. Most frequent job titles
-- ---------------------------------------------------------

SELECT TOP (10)
    'Original' AS population,
    LTRIM(RTRIM(p.job_title)) AS value,
    COUNT(*) AS job_count,
    CAST(100.0 * COUNT(*) / 8610 AS DECIMAL(5,2)) AS percentage
FROM analysis.refined_ba_us_jobs r
JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link
GROUP BY LTRIM(RTRIM(p.job_title))
ORDER BY job_count DESC;


SELECT TOP (10)
    'Sensitivity' AS population,
    LTRIM(RTRIM(p.job_title)) AS value,
    COUNT(*) AS job_count,
    CAST(100.0 * COUNT(*) / 8176 AS DECIMAL(5,2)) AS percentage
FROM #ba_us_sensitivity r
JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link
GROUP BY LTRIM(RTRIM(p.job_title))
ORDER BY job_count DESC;


-- ---------------------------------------------------------
-- B. Most frequent complementary skills
-- ---------------------------------------------------------

SELECT TOP (10)
    'Original' AS population,
    LTRIM(RTRIM(s.value)) AS value,
    COUNT(DISTINCT r.job_link) AS job_count,
    CAST(
        100.0 * COUNT(DISTINCT r.job_link) / 8610
        AS DECIMAL(5,2)
    ) AS percentage
FROM analysis.refined_ba_us_jobs r
JOIN raw.job_skills js
    ON r.job_link = js.job_link
CROSS APPLY STRING_SPLIT(js.job_skills, ',') s
WHERE LTRIM(RTRIM(s.value)) <> ''
  AND LOWER(LTRIM(RTRIM(s.value))) NOT IN
      ('business analysis', 'business analyst')
GROUP BY LTRIM(RTRIM(s.value))
ORDER BY job_count DESC;


SELECT TOP (10)
    'Sensitivity' AS population,
    LTRIM(RTRIM(s.value)) AS value,
    COUNT(DISTINCT r.job_link) AS job_count,
    CAST(
        100.0 * COUNT(DISTINCT r.job_link) / 8176
        AS DECIMAL(5,2)
    ) AS percentage
FROM #ba_us_sensitivity r
JOIN raw.job_skills js
    ON r.job_link = js.job_link
CROSS APPLY STRING_SPLIT(js.job_skills, ',') s
WHERE LTRIM(RTRIM(s.value)) <> ''
  AND LOWER(LTRIM(RTRIM(s.value))) NOT IN
      ('business analysis', 'business analyst')
GROUP BY LTRIM(RTRIM(s.value))
ORDER BY job_count DESC;


-- ---------------------------------------------------------
-- C. Most frequent advertised job locations
-- ---------------------------------------------------------

SELECT TOP (10)
    'Original' AS population,
    p.job_location AS value,
    COUNT(*) AS job_count,
    CAST(100.0 * COUNT(*) / 8610 AS DECIMAL(5,2)) AS percentage
FROM analysis.refined_ba_us_jobs r
JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link
GROUP BY p.job_location
ORDER BY job_count DESC;


SELECT TOP (10)
    'Sensitivity' AS population,
    p.job_location AS value,
    COUNT(*) AS job_count,
    CAST(100.0 * COUNT(*) / 8176 AS DECIMAL(5,2)) AS percentage
FROM #ba_us_sensitivity r
JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link
GROUP BY p.job_location
ORDER BY job_count DESC;

-- =========================================================
-- Query 31. Compare advertised job_location
--           with scraper search_city
-- =========================================================

WITH location_comparison AS
(
    SELECT
        job_link,
        LTRIM(RTRIM(search_city)) AS search_city,
        LTRIM(RTRIM(job_location)) AS job_location,

        -- Take the first part of job_location before the comma.
        -- Example: 'New York, NY' -> 'New York'
        LOWER(
            LTRIM(RTRIM(
                CASE
                    WHEN CHARINDEX(',', job_location) > 0
                    THEN LEFT(job_location, CHARINDEX(',', job_location) - 1)
                    ELSE job_location
                END
            ))
        ) AS advertised_city,

        LOWER(LTRIM(RTRIM(search_city))) AS normalized_search_city

    FROM raw.linkedin_job_postings
)

SELECT
    COUNT(*) AS total_job_postings,

    SUM(
        CASE
            WHEN search_city IS NULL OR search_city = ''
            THEN 1 ELSE 0
        END
    ) AS missing_search_city,

    SUM(
        CASE
            WHEN job_location IS NULL OR job_location = ''
            THEN 1 ELSE 0
        END
    ) AS missing_job_location,

    SUM(
        CASE
            WHEN normalized_search_city = advertised_city
            THEN 1 ELSE 0
        END
    ) AS matching_city,

    SUM(
        CASE
            WHEN normalized_search_city <> advertised_city
            THEN 1 ELSE 0
        END
    ) AS nonmatching_city,

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN normalized_search_city <> advertised_city
                THEN 1 ELSE 0
            END
        )
        /
        COUNT(*)
        AS DECIMAL(5,2)
    ) AS percentage_nonmatching

FROM location_comparison;


-- =========================================================
-- Query 32. Create scoped dataset for variable-level
--           data quality assessment and cleaning
-- =========================================================

/*
Purpose:
Create a permanent one-row-per-job dataset containing the
8,610 advertisements in the finalized U.S. Business Analyst
Iteration 1 scope.

This table is the handoff point between:
    1. Dataset-level assessment and scope definition
    2. Variable-level data quality assessment and cleaning

No variable-level cleaning is performed in this query.

LEFT JOIN is used for job_skills and job_summary so that jobs
are not removed simply because a linked skills or summary
record is unavailable.
*/

DROP TABLE IF EXISTS analysis.ba_us_variable_dqa;

SELECT
    r.job_link,
    p.job_title,
    p.company,
    p.job_location,
    p.search_country,
    p.first_seen,
    js.job_skills,
    s.job_summary

INTO analysis.ba_us_variable_dqa

FROM analysis.refined_ba_us_jobs r

JOIN raw.linkedin_job_postings p
    ON r.job_link = p.job_link

LEFT JOIN raw.job_skills js
    ON r.job_link = js.job_link

LEFT JOIN raw.job_summary s
    ON r.job_link = s.job_link;


-- =========================================================
-- Verification
-- The handoff dataset should contain the complete
-- 8,610-job scoped analytical population.
-- =========================================================

SELECT
    COUNT(*) AS handoff_population
FROM analysis.ba_us_variable_dqa;

analysis.ba_us_variable_dqa