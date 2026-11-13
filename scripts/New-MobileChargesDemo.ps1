[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SitePath,
    [Parameter(Mandatory = $true)][string]$Server,
    [Parameter(Mandatory = $true)][string]$Database,
    [Parameter(Mandatory = $true)][string]$IdentityDatabase
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Data
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'LeaseInvoice'
$destination = [IO.Path]::GetFullPath($SitePath)
if (Test-Path -LiteralPath $destination) { throw 'Choose a new staging directory; existing sites are never overwritten.' }
$assembly = Join-Path $source 'bin\ExcelDataReader.dll'
if (-not (Test-Path -LiteralPath $assembly -PathType Leaf)) {
    throw 'Restore the declared ExcelDataReader package before preparing the demo.'
}
foreach ($value in @($Server, $Database, $IdentityDatabase)) {
    if ([string]::IsNullOrWhiteSpace($value)) { throw 'Explicit SQL target names are required.' }
}
foreach ($catalog in @($Database, $IdentityDatabase)) {
    if ($catalog -in @('CUS', 'master', 'model', 'msdb', 'tempdb')) {
        throw 'A demo cannot target legacy CUS or a system database.'
    }
}

$config = New-Object System.Xml.XmlDocument
$config.XmlResolver = $null
$config.Load((Join-Path $source 'MobileCharges.config.example'))
foreach ($entry in $config.SelectNodes('/configuration/connectionStrings/add')) {
    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source'] = $Server
    $builder['Initial Catalog'] = $Database
    if ($entry.GetAttribute('name') -eq 'MobileChargesIdentityConnectionString') {
        $builder['Initial Catalog'] = $IdentityDatabase
    }
    $builder['Integrated Security'] = $true
    $builder['Encrypt'] = $true
    $builder['TrustServerCertificate'] = $false
    $entry.SetAttribute('connectionString', $builder.ConnectionString)
}
$config.SelectSingleNode('/configuration/appSettings/add[@key="MobileChargesReturnUrl"]').
    SetAttribute('value', '~/Default.aspx')
# The demo is deliberately read-only until a separate publication target and
# explicit publisher identity have been approved.
$config.SelectSingleNode('/configuration/appSettings/add[@key="MobileChargesPublishers"]').
    SetAttribute('value', '')
$web = $config.SelectSingleNode('/configuration/system.web')
$authentication = $config.CreateElement('authentication')
$authentication.SetAttribute('mode', 'Windows')
$null = $web.AppendChild($authentication)
$authorization = $config.CreateElement('authorization')
$deny = $config.CreateElement('deny')
$deny.SetAttribute('users', '?')
$null = $authorization.AppendChild($deny)
$null = $web.AppendChild($authorization)
$errors = $config.CreateElement('customErrors')
$errors.SetAttribute('mode', 'On')
$null = $web.AppendChild($errors)
$cookies = $config.CreateElement('httpCookies')
$cookies.SetAttribute('httpOnlyCookies', 'true')
$cookies.SetAttribute('requireSSL', 'true')
$null = $web.AppendChild($cookies)

$null = New-Item -ItemType Directory -Path $destination
Copy-Item -LiteralPath (Join-Path $source 'App_Code') -Destination $destination -Recurse
foreach ($file in @('rptMCMUserPeriodDetail.aspx', 'rptMCMUserPeriodDetail.aspx.vb',
    'MobileChargesUpload.aspx', 'MobileChargesUpload.aspx.vb')) {
    Copy-Item -LiteralPath (Join-Path $source $file) -Destination $destination
}
$null = New-Item -ItemType Directory -Path (Join-Path $destination 'bin')
Copy-Item -LiteralPath $assembly -Destination (Join-Path $destination 'bin')
Copy-Item -LiteralPath (Join-Path $root 'tests\fixtures\MobileChargesDemo\Default.aspx') -Destination $destination
$config.Save((Join-Path $destination 'web.config'))
Write-Output 'Prepared a separate read-only demo site. No IIS or SQL changes were made.'
Write-Output 'Hosting still requires CLR v4 IIS, ASP.NET 4.x, Windows Authentication, anonymous access disabled, HTTPS and an approved SQL runtime identity.'
Write-Output 'Uploads are disabled. The offline deployment preflight will report the intentionally empty publisher allowlist.'
