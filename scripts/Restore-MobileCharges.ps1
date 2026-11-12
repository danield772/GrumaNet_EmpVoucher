$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$package = Join-Path $root 'packages\ExcelDataReader.3.7.0'
$archive = Join-Path $root 'packages\ExcelDataReader.3.7.0.zip'
$bin = Join-Path $root 'LeaseInvoice\bin'
$dll = Join-Path $package 'lib\net462\ExcelDataReader.dll'
if (-not (Test-Path -LiteralPath $dll)) {
    $null = New-Item -ItemType Directory -Force -Path (Join-Path $root 'packages')
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        Invoke-WebRequest -UseBasicParsing -Uri 'https://api.nuget.org/v3-flatcontainer/exceldatareader/3.7.0/exceldatareader.3.7.0.nupkg' -OutFile $archive
        Expand-Archive -LiteralPath $archive -DestinationPath $package -Force
    }
    finally {
        if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive }
    }
}
$null = New-Item -ItemType Directory -Force -Path $bin
Copy-Item -LiteralPath $dll -Destination $bin
Write-Output 'Restored ExcelDataReader 3.7.0 for .NET Framework 4.6.2+.'
