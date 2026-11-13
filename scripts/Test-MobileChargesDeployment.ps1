[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SitePath
)

$ErrorActionPreference = 'Stop'
$failures = New-Object 'System.Collections.Generic.List[string]'
$reader = $null

try {
    Add-Type -AssemblyName System.Data
    $site = (Resolve-Path -LiteralPath $SitePath).ProviderPath
    if (-not (Test-Path -LiteralPath $site -PathType Container)) {
        throw 'INVALID_SITE'
    }

    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create((Join-Path $site 'web.config'), $settings)
    $config = New-Object System.Xml.XmlDocument
    $config.XmlResolver = $null
    $config.Load($reader)

    $release = Get-ItemPropertyValue -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release
    if ($release -lt 461308) {
        $failures.Add('This machine requires .NET Framework 4.7.1 or later.')
    }

    $connections = @{}
    foreach ($name in @('MobileChargesConnectionString', 'MobileChargesPublisherConnectionString', 'MobileChargesIdentityConnectionString')) {
        $entry = $config.SelectSingleNode('/configuration/connectionStrings/add[@name="' + $name + '"]')
        try {
            if ($null -eq $entry -or $entry.GetAttribute('providerName') -ne 'System.Data.SqlClient') {
                throw 'MISSING_SETTING'
            }
            $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder($entry.GetAttribute('connectionString'))
            if ([string]::IsNullOrWhiteSpace($builder.DataSource) -or
                [string]::IsNullOrWhiteSpace($builder.InitialCatalog) -or
                $builder.DataSource -match 'APPROVED_|REPLACE_' -or
                $builder.InitialCatalog -match 'APPROVED_|REPLACE_' -or
                $builder.InitialCatalog -in @('CUS', 'master', 'msdb', 'model', 'tempdb') -or
                -not [string]::IsNullOrWhiteSpace($builder.AttachDBFilename)) {
                throw 'INVALID_TARGET'
            }
            $connections[$name] = $builder
        }
        catch {
            $failures.Add("$name must be an explicit, non-placeholder SqlClient server connection to an approved non-system database, not CUS.")
        }
    }
    $read = $connections['MobileChargesConnectionString']
    $publish = $connections['MobileChargesPublisherConnectionString']
    if ($null -ne $read -and $null -ne $publish -and
        ($read.DataSource -ne $publish.DataSource -or $read.InitialCatalog -ne $publish.InitialCatalog)) {
        $failures.Add('Employee and publisher connections must target the same snapshot database and server.')
    }

    $publisher = $config.SelectSingleNode('/configuration/appSettings/add[@key="MobileChargesPublishers"]')
    if ($null -eq $publisher -or [string]::IsNullOrWhiteSpace($publisher.GetAttribute('value'))) {
        $failures.Add('An explicitly approved MobileChargesPublishers allowlist is required.')
    }
    else {
        foreach ($login in $publisher.GetAttribute('value').Split(';')) {
            if ($login.Trim() -notmatch '\A[^\\;\s]+\\[^\\;\s]+\z' -or $login -match '[*?]') {
                $failures.Add('Publisher entries must be explicit DOMAIN\login values, not wildcards or empty entries.')
                break
            }
        }
    }

    $returnEntry = $config.SelectSingleNode('/configuration/appSettings/add[@key="MobileChargesReturnUrl"]')
    $returnPath = if ($null -ne $returnEntry) { $returnEntry.GetAttribute('value') } else { '' }
    if ($returnPath -notmatch '\A~/(?!/)[A-Za-z0-9_./-]+\.aspx\z' -or
        $returnPath.Contains('..') -or $returnPath -match 'REPLACE_') {
        $failures.Add('MobileChargesReturnUrl must name the actual application-local Asset Voucher .aspx page.')
    }
    elseif (-not (Test-Path -LiteralPath (Join-Path $site ($returnPath.Substring(2).Replace('/', '\'))) -PathType Leaf)) {
        $failures.Add('The configured Asset Voucher return page does not exist in this site copy.')
    }

    foreach ($file in @(
        'rptMCMUserPeriodDetail.aspx', 'rptMCMUserPeriodDetail.aspx.vb',
        'MobileChargesUpload.aspx', 'MobileChargesUpload.aspx.vb',
        'App_Code\MobileCharges\Access.vb', 'App_Code\MobileCharges\Models.vb',
        'App_Code\MobileCharges\Store.vb', 'App_Code\MobileCharges\Workbook.vb'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $site $file) -PathType Leaf)) {
            $failures.Add("Missing overlay file: $file")
        }
    }
    try {
        $assembly = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $site 'bin\ExcelDataReader.dll'))
        if ($assembly.Name -ne 'ExcelDataReader' -or $assembly.Version -ne [version]'3.7.0.0') {
            throw 'UNEXPECTED_ASSEMBLY'
        }
    }
    catch {
        $failures.Add('The declared ExcelDataReader 3.7.0 runtime assembly is missing or does not match.')
    }

    $compression = $config.SelectSingleNode('/configuration/system.web/compilation/assemblies/add[starts-with(@assembly,"System.IO.Compression,")]')
    if ($null -eq $compression) {
        $failures.Add('Confirm an explicit System.IO.Compression framework assembly reference for Web Site compilation.')
    }

    $aspLimit = $config.SelectSingleNode('/configuration/location[@path="MobileChargesUpload.aspx"]/system.web/httpRuntime')
    $iisLimit = $config.SelectSingleNode('/configuration/location[@path="MobileChargesUpload.aspx"]/system.webServer/security/requestFiltering/requestLimits')
    if ($null -eq $aspLimit -or $aspLimit.GetAttribute('maxRequestLength') -ne '11264' -or
        $null -eq $iisLimit -or $iisLimit.GetAttribute('maxAllowedContentLength') -ne '11534336') {
        $failures.Add('Merge the reviewed page-scoped upload limits from MobileCharges.config.example.')
    }
}
catch {
    $failures.Add('The site configuration or local runtime could not be inspected. Review locally without sharing credentials.')
}
finally {
    if ($null -ne $reader) { $reader.Dispose() }
}

foreach ($failure in $failures) { [Console]::Error.WriteLine("FAIL: $failure") }
if ($failures.Count -gt 0) { exit 1 }
Write-Output 'PASS: Local overlay files, settings, assembly and installed Framework passed preflight.'
Write-Output 'NOT VERIFIED: DBA approval, SQL version/procedures/permissions, identity mapping, IIS pool/authentication/HTTPS, effective inherited configuration, and legacy-report regressions.'
Write-Output 'No SQL connection, IIS change, or deployment was performed. A local pass does not authorize deployment.'
exit 0
