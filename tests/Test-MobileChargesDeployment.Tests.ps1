$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$probe = Join-Path $root 'scripts\Test-MobileChargesDeployment.ps1'
$testRoot = Join-Path $root 'tests\bin'
$site = Join-Path $testRoot ('Preflight-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Force -Path $site
$sentinel = 'synthetic-secret-not-for-output'
$passed = 0

function Invoke-Case([string]$name, [string]$content, [int]$expectedExit, [string]$expectedMessage) {
    [IO.File]::WriteAllText((Join-Path $site 'web.config'), $content)
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = Join-Path $PSHOME 'powershell.exe'
    $start.Arguments = '-NoProfile -NonInteractive -File "' + $probe + '" -SitePath "' + $site + '"'
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($start)
    try {
        $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne $expectedExit -or
            -not $output.Contains($expectedMessage) -or $output.Contains($sentinel)) {
            throw "FAIL: deployment preflight case $name"
        }
        if ($expectedExit -ne 0 -and $output.Contains('PASS:')) { throw "False success: $name" }
    }
    finally { $process.Dispose() }
    $script:passed++
    Write-Output "PASS: $name"
}

try {
    Copy-Item -Path (Join-Path $root 'LeaseInvoice\*') -Destination $site -Recurse
    [IO.File]::WriteAllText((Join-Path $site 'AssetVoucher.aspx'), '<%@ Page Language="VB" %>')
    $template = Get-Content (Join-Path $root 'LeaseInvoice\MobileCharges.config.example') -Raw
    $valid = $template.Replace('APPROVED_SERVER', 'synthetic-server').
        Replace('APPROVED_IDENTITY_DATABASE', 'SyntheticIdentity').
        Replace('APPROVED_DATABASE', 'SyntheticMobile').
        Replace('key="MobileChargesPublishers" value=""', 'key="MobileChargesPublishers" value="EXAMPLE\publisher"').
        Replace('~/REPLACE_WITH_EXISTING_ASSET_VOUCHER_PATH.aspx', '~/AssetVoucher.aspx').
        Replace('Integrated Security=True;', ('User ID=synthetic;Password=' + $sentinel + ';'))

    Invoke-Case 'configured copy (no SQL connection)' $valid 0 'NOT VERIFIED:'
    Invoke-Case 'example placeholders rejected' $template 1 'non-placeholder'
    Invoke-Case 'legacy CUS rejected' ($valid.Replace('SyntheticMobile', 'CUS')) 1 'not CUS'
    $different = [xml]$valid
    $publisherConnection = $different.SelectSingleNode('/configuration/connectionStrings/add[@name="MobileChargesPublisherConnectionString"]')
    $publisherConnection.SetAttribute('connectionString', $publisherConnection.GetAttribute('connectionString').Replace('SyntheticMobile', 'OtherSnapshot'))
    Invoke-Case 'different snapshot database rejected' $different.OuterXml 1 'same snapshot database'
    Invoke-Case 'missing publisher connection' ($valid.Replace(
        'name="MobileChargesPublisherConnectionString" providerName="System.Data.SqlClient"',
        'name="UnusedPublisherConnectionString" providerName="System.Data.SqlClient"')) 1 'MobileChargesPublisherConnectionString'
    Invoke-Case 'missing return page' ($valid.Replace('~/AssetVoucher.aspx', '~/Missing.aspx')) 1 'does not exist'
    Invoke-Case 'external redirect rejected' ($valid.Replace('~/AssetVoucher.aspx', 'https://example.invalid')) 1 'application-local'
    Invoke-Case 'publisher wildcard rejected' ($valid.Replace('EXAMPLE\publisher', 'EXAMPLE\*')) 1 'wildcards'
    Invoke-Case 'missing upload limits' ($valid.Replace('11264', '1')) 1 'page-scoped'
    Invoke-Case 'malformed XML sanitized' ('<configuration>' + $sentinel) 1 'could not be inspected'
    Invoke-Case 'DTD prohibited' ('<!DOCTYPE configuration [<!ENTITY x "' + $sentinel + '">]><configuration>&x;</configuration>') 1 'could not be inspected'
    Remove-Item -LiteralPath (Join-Path $site 'bin\ExcelDataReader.dll')
    Invoke-Case 'missing assembly' $valid 1 'runtime assembly'
    Write-Output "PASS: $passed deployment preflight cases."
}
finally {
    Remove-Item -LiteralPath $site -Recurse
}
