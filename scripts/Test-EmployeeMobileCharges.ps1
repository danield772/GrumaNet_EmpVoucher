$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$compiler = Join-Path $framework 'vbc.exe'
$excel = Join-Path $root 'LeaseInvoice\bin\ExcelDataReader.dll'
if (-not (Test-Path -LiteralPath $excel)) {
    throw 'ExcelDataReader is missing. Run scripts\Restore-MobileCharges.ps1 first.'
}
$output = Join-Path $root 'tests\bin'
$null = New-Item -ItemType Directory -Force -Path $output
$sources = @(Get-ChildItem (Join-Path $root 'LeaseInvoice\App_Code\MobileCharges') -Filter '*.vb' | ForEach-Object { $_.FullName })
$references = @('System.dll', 'System.Core.dll', 'System.Data.dll', 'System.Xml.dll', 'System.Web.dll', 'System.Configuration.dll', 'System.IO.Compression.dll')
$arguments = @('/nologo', '/optionstrict+', '/target:library', ('/sdkpath:' + $framework),
    ('/out:' + (Join-Path $output 'MobileChargesTests.dll')), ('/reference:' + $excel))
foreach ($reference in $references) { $arguments += '/reference:' + (Join-Path $framework $reference) }
& $compiler @arguments @sources (Join-Path $root 'tests\MobileChargesTests.vb')
if ($LASTEXITCODE -ne 0) { throw 'VB.NET compilation failed.' }
Copy-Item -LiteralPath $excel -Destination $output
$null = [Reflection.Assembly]::LoadFrom((Join-Path $output 'ExcelDataReader.dll'))
$assembly = [Reflection.Assembly]::LoadFrom((Join-Path $output 'MobileChargesTests.dll'))
$entry = $assembly.GetType('MobileChargesTests').GetMethod('Main', [Reflection.BindingFlags]'Public,NonPublic,Static')
$null = $entry.Invoke($null, @())
