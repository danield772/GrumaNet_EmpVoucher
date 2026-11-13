$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$site = Join-Path $root ('tests\bin\DemoFixture-' + [Guid]::NewGuid().ToString('N'))
$compiled = $site + '-compiled'
function Assert($condition, [string]$message) {
    if (-not $condition) { throw $message }
}
try {
    & (Join-Path $root 'scripts\New-MobileChargesDemo.ps1') -SitePath $site `
        -Server 'DEMO_SERVER' -Database 'DEMO_DATA' -IdentityDatabase 'DEMO_IDENTITY'
    $config = New-Object System.Xml.XmlDocument
    $config.XmlResolver = $null
    $config.Load((Join-Path $site 'web.config'))
    Assert ($config.SelectSingleNode('/configuration/system.web/authentication').GetAttribute('mode') -eq 'Windows') 'Windows authentication is required.'
    Assert ($config.SelectSingleNode('/configuration/system.web/authorization/deny').GetAttribute('users') -eq '?') 'Anonymous application access must be denied.'
    Assert ($config.SelectSingleNode('/configuration/system.web/httpCookies').GetAttribute('requireSSL') -eq 'true') 'Demo cookies must require HTTPS.'
    Assert ($config.SelectSingleNode('/configuration/appSettings/add[@key="MobileChargesPublishers"]').GetAttribute('value') -eq '') 'Demo publication must be disabled.'
    Assert ($config.SelectSingleNode('/configuration/appSettings/add[@key="MobileChargesReturnUrl"]').GetAttribute('value') -eq '~/Default.aspx') 'Demo return route must be local.'
    Assert ($config.SelectNodes('/configuration/connectionStrings/add').Count -eq 3) 'Three dedicated connections are required.'
    foreach ($entry in $config.SelectNodes('/configuration/connectionStrings/add')) {
        $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder($entry.GetAttribute('connectionString'))
        $expected = 'DEMO_DATA'
        if ($entry.GetAttribute('name') -eq 'MobileChargesIdentityConnectionString') { $expected = 'DEMO_IDENTITY' }
        Assert ($builder.InitialCatalog -eq $expected) 'Incorrect connection target.'
        Assert ($builder.IntegratedSecurity -and $builder.Encrypt -and -not $builder.TrustServerCertificate) 'Connections must retain secure settings.'
    }
    Assert (Test-Path -LiteralPath (Join-Path $site 'Default.aspx')) 'Demo landing page is missing.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $site 'rptMCMCostCenterDetail.aspx'))) 'A legacy report was unexpectedly copied.'
    $rejected = $false
    try {
        & (Join-Path $root 'scripts\New-MobileChargesDemo.ps1') -SitePath $site `
            -Server 'DEMO_SERVER' -Database 'DEMO_DATA' -IdentityDatabase 'DEMO_IDENTITY'
    }
    catch {
        if ($_.Exception.Message -notlike '*existing sites are never overwritten*') { throw }
        $rejected = $true
    }
    Assert $rejected 'Existing site was not protected.'
    $rejected = $false
    try {
        & (Join-Path $root 'scripts\New-MobileChargesDemo.ps1') -SitePath ($site + '-invalid') `
            -Server 'DEMO_SERVER' -Database 'CUS' -IdentityDatabase 'DEMO_IDENTITY'
    }
    catch {
        if ($_.Exception.Message -notlike '*legacy CUS or a system database*') { throw }
        $rejected = $true
    }
    Assert $rejected 'Forbidden database was not rejected.'
    Assert (-not (Test-Path -LiteralPath ($site + '-invalid'))) 'Rejected configuration created a directory.'
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe'
    & $compiler -v /MobileChargesDemo -p $site $compiled
    if ($LASTEXITCODE -ne 0) { throw 'Demo site precompilation failed.' }
    Write-Output 'PASS: Demo configuration safeguards, existing-site protection and all three ASP.NET pages compiled.'
}
finally {
    if (Test-Path -LiteralPath $site) { Remove-Item -LiteralPath $site -Recurse }
    if (Test-Path -LiteralPath $compiled) { Remove-Item -LiteralPath $compiled -Recurse }
}
