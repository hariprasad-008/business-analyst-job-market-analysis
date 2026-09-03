# Business Analyst Job Market Analysis

Analysis of LinkedIn job postings requiring Business Analysis capability, using the
["1.3M LinkedIn Jobs and Skills (2024)"](https://www.kaggle.com/datasets/asaniczka/1-3m-linkedin-jobs-and-skills-2024)
dataset (Kaggle, published by asaniczka).

## Research questions

The analysis focuses on three questions: what types of job roles require Business
Analysis capability, what complementary skills and requirements are most frequently
listed alongside that capability, and where these opportunities are geographically
located using the advertised job_location field.

## Repository structure

- `SQL Queries/` : SQL queries used to define and validate the analytical population
- `Python Notebook/` : Jupyter notebook (data-analysis.ipynb) covering data cleaning, population
  validation, role classification, skill normalisation, and geographic extraction
- `Cleaned Dataset/` : analysis-ready output files:
  - `ba_refined_postings_final.csv` : one row per job posting (8,610 rows)
  - `ba_refined_skills_final.csv` : one row per individual skill, linked via `job_link`
    (226,269 rows; provided as a zip due to GitHub's upload size limit, unzip before use)
- `Tableau Files/` : each group member's `.twbx` visualisation workbook

## How to reproduce

1. Raw source data is not included here due to size, download it from the Kaggle
   link above if you need to run the cleaning process from scratch.
2. Run the notebook in `python/` to reproduce the cleaning, population definition, and
   analysis, or refer to the queries in `sql/` for the parallel SQL-based approach.
3. Open any `.twbx` file in `tableau/` (requires Tableau Desktop or Tableau Public) to
   view the visualisations.
