-- Run in SSMS as a DBA on the instance from the deployed MCMConnectionString.
-- Read-only: no employee rows, passwords, database changes, or permission grants.
USE [master];
GO

SELECT
    SERVERPROPERTY('ServerName') AS connected_instance,
    name AS database_name,
    state_desc,
    user_access_desc
FROM sys.databases
WHERE name = N'CUS';

SELECT name AS login_name, type_desc, is_disabled
FROM sys.server_principals
WHERE name = N'MisWebusr';

IF DB_ID(N'CUS') IS NULL
BEGIN
    RAISERROR('CUS is absent or not visible. Verify the configured SQL instance; do not create an empty replacement database.', 16, 1);
    RETURN;
END;

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = N'CUS' AND state_desc <> N'ONLINE')
BEGIN
    RAISERROR('CUS is not ONLINE. A DBA must investigate its availability before changing permissions.', 16, 1);
    RETURN;
END;

EXEC sys.sp_executesql N'
USE [CUS];
SELECT
    dp.name AS database_user,
    dp.type_desc,
    dp.default_schema_name,
    CASE WHEN dp.sid = SUSER_SID(N''MisWebusr'') THEN 1 ELSE 0 END AS sid_matches_login
FROM sys.database_principals AS dp
WHERE dp.name = N''MisWebusr'' OR dp.sid = SUSER_SID(N''MisWebusr'');

SELECT
    SCHEMA_NAME(schema_id) AS object_schema,
    name AS object_name,
    type_desc
FROM sys.objects
WHERE name IN (N''MCM_Movs'', N''vw_peopledevice'');

SELECT
    dp.name AS database_user,
    permission.state_desc,
    permission.permission_name,
    permission.class_desc,
    OBJECT_SCHEMA_NAME(permission.major_id) AS object_schema,
    OBJECT_NAME(permission.major_id) AS object_name
FROM sys.database_permissions AS permission
JOIN sys.database_principals AS dp ON dp.principal_id = permission.grantee_principal_id
WHERE dp.name = N''MisWebusr'' OR dp.sid = SUSER_SID(N''MisWebusr'');

SELECT member.name AS database_user, role.name AS database_role
FROM sys.database_role_members AS membership
JOIN sys.database_principals AS member ON member.principal_id = membership.member_principal_id
JOIN sys.database_principals AS role ON role.principal_id = membership.role_principal_id
WHERE member.name = N''MisWebusr'' OR member.sid = SUSER_SID(N''MisWebusr'');
';
