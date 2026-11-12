-- DBA only. Read docs/mobile-charges-database-access.md before applying.
-- This does not create databases/logins, reset passwords, or enable logins.
USE [master];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply bit;
SET @Apply = 0; -- Set to 1 only after reviewing diagnosis and approving the grants.

IF DB_ID(N'CUS') IS NULL OR
   NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = N'CUS' AND state_desc = N'ONLINE')
BEGIN
    RAISERROR('CUS must exist and be ONLINE on the correct SQL instance. No changes were made.', 16, 1);
    RETURN;
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.server_principals
    WHERE name = N'MisWebusr' AND type = 'S' AND is_disabled = 0
)
BEGIN
    RAISERROR('The existing MisWebusr SQL login must be enabled. Ask the DBA to resolve the login first.', 16, 1);
    RETURN;
END;

IF @Apply = 0
BEGIN
    SELECT N'Preview only: on CUS, map MisWebusr to the existing login, grant CONNECT, and grant SELECT on dbo.MCM_Movs and the unique vw_peopledevice view. No changes were made.' AS planned_action;
    RETURN;
END;

EXEC sys.sp_executesql N'
USE [CUS];
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N''dbo.MCM_Movs'', N''U'') IS NULL
        RAISERROR(''Expected dbo.MCM_Movs table is missing. No replacement objects will be created.'', 16, 1);

    IF (SELECT COUNT(*) FROM sys.views WHERE name = N''vw_peopledevice'') <> 1
        RAISERROR(''Expected exactly one vw_peopledevice view. Confirm the page query schema before granting access.'', 16, 1);

    IF EXISTS (
        SELECT 1 FROM sys.database_principals
        WHERE sid = SUSER_SID(N''MisWebusr'') AND name <> N''MisWebusr''
    )
        RAISERROR(''This login is already mapped under another database user. Review that mapping manually.'', 16, 1);

    IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''MisWebusr'' AND type <> ''S'')
        RAISERROR(''MisWebusr is not a SQL database user. Review this principal manually.'', 16, 1);

    IF USER_ID(N''MisWebusr'') IS NULL
        CREATE USER [MisWebusr] FOR LOGIN [MisWebusr];
    ELSE
        ALTER USER [MisWebusr] WITH LOGIN = [MisWebusr];

    GRANT CONNECT TO [MisWebusr];
    GRANT SELECT ON OBJECT::[dbo].[MCM_Movs] TO [MisWebusr];

    DECLARE @GrantView nvarchar(max);
    SELECT @GrantView = N''GRANT SELECT ON OBJECT::'' +
        QUOTENAME(SCHEMA_NAME(schema_id)) + N''.'' + QUOTENAME(name) +
        N'' TO [MisWebusr];''
    FROM sys.views
    WHERE name = N''vw_peopledevice'';
    EXEC sys.sp_executesql @GrantView;

    COMMIT TRANSACTION;
    SELECT N''Applied user mapping, CONNECT, and object-level SELECT grants. Run the application-account probe to verify effective access.'' AS result;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    DECLARE @Error nvarchar(4000);
    SET @Error = ERROR_MESSAGE();
    RAISERROR(''%s'', 16, 1, @Error);
END CATCH;
';
