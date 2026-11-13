-- Verified source: MainInv.dbo.people.LOGONID -> sap_number, not peopleid.
-- Review in the approved identity database; enable @Apply in a local copy.
-- Never replace an existing procedure without reviewing its definition.
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @Apply bit = 0;
IF @Apply = 0 OR DB_NAME() <> N'MainInv'
    OR OBJECT_ID(N'dbo.people', N'U') IS NULL
    OR COL_LENGTH(N'dbo.people', N'LOGONID') IS NULL
    OR COL_LENGTH(N'dbo.people', N'sap_number') IS NULL
    OR OBJECT_ID(N'dbo.MobileChargesResolveEmployee') IS NOT NULL
BEGIN
    PRINT 'Not installing: review the approved identity database, source columns, existing objects and @Apply switch.';
    SET NOEXEC ON;
END;
GO
CREATE PROCEDURE dbo.MobileChargesResolveEmployee
    @Login nvarchar(256)
AS
BEGIN
    SET NOCOUNT ON;
    -- Preserve missing, null and duplicate results for the application's
    -- fail-closed resolver; TOP/DISTINCT would hide ambiguous mappings.
    SELECT CONVERT(nvarchar(64), sap_number) AS EmployeeNumber
    FROM dbo.people
    WHERE LOGONID = @Login;
END;
GO
-- Grant only EXECUTE on this procedure to the approved identity principal.
-- No writes or grants on dbo.people, and no new identity table.
SET NOEXEC OFF;
