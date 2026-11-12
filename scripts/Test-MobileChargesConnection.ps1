[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WebConfigPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Data

$connection = $null
$command = $null
$reader = $null

try {
    if (-not (Test-Path -LiteralPath $WebConfigPath -PathType Leaf)) {
        throw 'CONFIG_NOT_FOUND'
    }

    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create(
        (Resolve-Path -LiteralPath $WebConfigPath).ProviderPath, $settings)
    $config = New-Object System.Xml.XmlDocument
    $config.XmlResolver = $null
    $config.Load($reader)
    $entry = $config.SelectSingleNode(
        '/configuration/connectionStrings/add[@name="MCMConnectionString"]')

    if ($null -eq $entry -or -not $entry.HasAttribute('connectionString')) {
        throw 'CONNECTION_SETTING_NOT_FOUND'
    }

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder(
        $entry.GetAttribute('connectionString'))
    if ([string]::IsNullOrWhiteSpace($builder.DataSource) -or
        $builder.InitialCatalog -ne 'CUS' -or
        -not [string]::IsNullOrWhiteSpace($builder.AttachDBFilename)) {
        throw 'UNEXPECTED_CONNECTION_TARGET'
    }

    $builder['Connect Timeout'] = 15
    $connection = New-Object System.Data.SqlClient.SqlConnection($builder.ConnectionString)
    $connection.Open()
    Write-Output 'PASS: MCMConnectionString opened CUS.'

    $command = $connection.CreateCommand()
    $command.CommandTimeout = 15
    $command.CommandText = @'
SELECT TOP (0)
    t1.devicenumber, [Device Name] AS devicename, t1.carriername,
    username, t1.location, totalgbusage, totalamount,
    CONVERT(varchar, periodfrom, 101) + ' to ' +
    CONVERT(varchar, periodto, 101) AS UsagePeriod
FROM [CUS].[dbo].[MCM_Movs] AS t1
LEFT JOIN vw_peopledevice AS t2
    ON t1.peopleid = t2.peopleid
    AND REPLACE(REPLACE(REPLACE(REPLACE(t1.devicenumber,
        '(', ''), ')', ''), ' ', ''), '-', '') = t2.RawDeviceNumber
WHERE t1.peopleID = @peopleid
ORDER BY [ppyear] DESC, [ppmonth] DESC;
'@
    $null = $command.Parameters.Add('@peopleid', [System.Data.SqlDbType]::NVarChar, 40)
    $command.Parameters['@peopleid'].Value = '0'
    $null = $command.ExecuteNonQuery()
    Write-Output 'PASS: The existing mobile query compiled and passed permission checks without returning employee rows.'
    exit 0
}
catch [System.Data.SqlClient.SqlException] {
    $number = $_.Exception.Number
    switch ($number) {
        4060 { $reason = 'CUS cannot be opened. Check the SQL instance, database state, and login-to-database user mapping.' }
        18456 { $reason = 'SQL login was rejected. Ask the DBA to inspect the SQL Server error log for its failure state.' }
        916 { $reason = 'The login cannot access a required database.' }
        229 { $reason = 'The login lacks permission on a required SQL object.' }
        208 { $reason = 'A required SQL object was not found. Verify MCM_Movs and vw_peopledevice on this instance.' }
        207 { $reason = 'The deployed SQL object columns do not match the page query.' }
        default { $reason = 'The SQL probe failed. Ask the DBA to investigate this error number on the configured instance.' }
    }
    [Console]::Error.WriteLine("FAIL: SQL error $number. $reason")
    exit 1
}
catch {
    $code = $_.Exception.Message
    switch ($code) {
        'CONFIG_NOT_FOUND' { $reason = 'The specified web.config file was not found.' }
        'CONNECTION_SETTING_NOT_FOUND' { $reason = 'MCMConnectionString is absent or stored externally/encrypted. Inspect effective IIS configuration securely.' }
        'UNEXPECTED_CONNECTION_TARGET' { $reason = 'Expected a server connection to CUS with no attached database file. Review effective IIS configuration.' }
        default { $reason = 'Configuration could not be read or the probe could not run. Inspect it locally without sharing credentials.' }
    }
    [Console]::Error.WriteLine("FAIL: $reason")
    exit 1
}
finally {
    if ($null -ne $command) { $command.Dispose() }
    if ($null -ne $connection) { $connection.Dispose() }
    if ($null -ne $reader) { $reader.Dispose() }
}
