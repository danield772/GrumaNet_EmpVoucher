[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Server,
    [Parameter(Mandatory = $true)][string]$Database
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Data
$root = Split-Path $PSScriptRoot -Parent
$sql = Get-Content -LiteralPath (Join-Path $root 'database\MobileChargesIdentityContract.sql') -Raw
$batches = @([regex]::Split($sql, '(?im)^\s*GO\s*\r?$'))
$procedure = @($batches | Where-Object { $_ -match '(?im)^CREATE PROCEDURE dbo\.MobileChargesResolveEmployee' })
if ($procedure.Count -ne 1) { throw 'Identity procedure batch was not found exactly once.' }
$fixtureProcedure = $procedure[0].Replace('dbo.MobileChargesResolveEmployee', '#MobileChargesResolveEmployee').
    Replace('dbo.people', '#MobileIdentityPeople')
$builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$builder['Data Source'] = $Server
$builder['Initial Catalog'] = $Database
$builder['Integrated Security'] = $true
$builder['Connect Timeout'] = 15
$connection = New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
$command = $null
try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 30
    $command.CommandText = @'
CREATE TABLE #MobileIdentityPeople (LOGONID varchar(256), sap_number int NULL);
INSERT #MobileIdentityPeople VALUES
('DEMO\ONE',12345678),('DEMO\OTHER',87654321),
('DEMO\DUPLICATE',11111111),('DEMO\DUPLICATE',22222222),
('DEMO\SAME',33333333),('DEMO\SAME',33333333),
('DEMO\NULL',NULL);
'@
    $null = $command.ExecuteNonQuery()
    $command.CommandText = $fixtureProcedure
    $null = $command.ExecuteNonQuery()
    $command.CommandText = @'
CREATE TABLE #Actual (EmployeeNumber nvarchar(64));
INSERT #Actual EXEC #MobileChargesResolveEmployee @Login=N'DEMO\ONE';
IF (SELECT COUNT(*) FROM #Actual)<>1 OR NOT EXISTS
    (SELECT 1 FROM #Actual WHERE EmployeeNumber=N'12345678')
    THROW 50100, 'Exact login mapping failed.', 1;
TRUNCATE TABLE #Actual;
INSERT #Actual EXEC #MobileChargesResolveEmployee @Login=N'DEMO\MISSING';
IF EXISTS(SELECT 1 FROM #Actual) THROW 50100, 'Missing login mapping failed.', 1;
INSERT #Actual EXEC #MobileChargesResolveEmployee @Login=N'ONE';
IF EXISTS(SELECT 1 FROM #Actual) THROW 50100, 'Domain-qualified login mapping failed.', 1;
INSERT #Actual EXEC #MobileChargesResolveEmployee @Login=N'DEMO\DUPLICATE';
IF (SELECT COUNT(*) FROM #Actual)<>2 THROW 50100, 'Duplicate mappings were hidden.', 1;
TRUNCATE TABLE #Actual;
INSERT #Actual EXEC #MobileChargesResolveEmployee @Login=N'DEMO\SAME';
IF (SELECT COUNT(*) FROM #Actual)<>2 THROW 50100, 'Identical duplicate mappings were hidden.', 1;
TRUNCATE TABLE #Actual;
INSERT #Actual EXEC #MobileChargesResolveEmployee @Login=N'DEMO\NULL';
IF (SELECT COUNT(*) FROM #Actual)<>1 OR NOT EXISTS
    (SELECT 1 FROM #Actual WHERE EmployeeNumber IS NULL)
    THROW 50100, 'Null mapping was hidden.', 1;
TRUNCATE TABLE #Actual;
INSERT #Actual EXEC #MobileChargesResolveEmployee @Login=NULL;
IF EXISTS(SELECT 1 FROM #Actual) THROW 50100, 'Null login mapping failed.', 1;
INSERT #Actual EXEC #MobileChargesResolveEmployee @Login=N'';
IF EXISTS(SELECT 1 FROM #Actual) THROW 50100, 'Empty login mapping failed.', 1;
'@
    $null = $command.ExecuteNonQuery()
    Write-Output 'PASS: Eight identity SQL fixture cases; only connection-scoped temporary objects were used.'
}
finally {
    if ($null -ne $command) { $command.Dispose() }
    $connection.Dispose()
}
