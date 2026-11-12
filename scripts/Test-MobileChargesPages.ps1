$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\aspnet_compiler.exe'
$testRoot = Join-Path $root 'tests\bin'
$site = Join-Path $testRoot ('MobileSite-' + [Guid]::NewGuid().ToString('N'))
$compiled = $site + '-compiled'
if (-not (Test-Path (Join-Path $root 'LeaseInvoice\bin\ExcelDataReader.dll'))) {
    throw 'Restore ExcelDataReader before compiling the pages.'
}
$null = New-Item -ItemType Directory -Force -Path $site
try {
    Copy-Item -Path (Join-Path $root 'LeaseInvoice\*') -Destination $site -Recurse
    Copy-Item -LiteralPath (Join-Path $root 'LeaseInvoice\MobileCharges.config.example') -Destination (Join-Path $site 'web.config')
    & $compiler -v /EmployeeMobileCompile -p $site $compiled
    if ($LASTEXITCODE -ne 0) { throw 'ASP.NET page compilation failed.' }
    Write-Output 'PASS: Both isolated Web Forms pages and App_Code compiled.'
}
finally {
    Remove-Item -LiteralPath $site -Recurse
    if (Test-Path -LiteralPath $compiled) { Remove-Item -LiteralPath $compiled -Recurse }
}
