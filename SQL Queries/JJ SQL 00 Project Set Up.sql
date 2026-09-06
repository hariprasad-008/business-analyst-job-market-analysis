/*
SQL 00 - Project Setup

Related documentation:
Documentation 00 - Project Setup Log

Purpose:
Creates the project database structure and schemas.
*/
USE [LinkedIn_BI_Assignment];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw')
    EXEC('CREATE SCHEMA raw');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stage')
    EXEC('CREATE SCHEMA stage');

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'analysis')
    EXEC('CREATE SCHEMA analysis');

SELECT DB_NAME() AS CurrentDatabase;

SELECT name AS SchemaName
FROM sys.schemas
WHERE name IN ('raw', 'stage', 'analysis');