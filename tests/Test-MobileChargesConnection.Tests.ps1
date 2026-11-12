$ErrorActionPreference = 'Stop'
$probe = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts\Test-MobileChargesConnection.ps1'
$tokens = $null
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    $probe, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -gt 0) { throw 'Connection probe has PowerShell syntax errors.' }

$testDirectory = Join-Path $PSScriptRoot ([Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testDirectory
$configPath = Join-Path $testDirectory 'web.config'
$shell = Join-Path $PSHOME 'powershell.exe'
$sentinel = 'synthetic-value-not-for-output'
$cases = @(
    @{ Name = 'missing file'; Content = $null; Expected = 'file was not found' },
    @{ Name = 'missing setting'; Content = '<configuration><connectionStrings /></configuration>'; Expected = 'absent or stored externally/encrypted' },
    @{ Name = 'wrong catalog'; Content = '<configuration><connectionStrings><add name="MCMConnectionString" connectionString="Data Source=unused;Initial Catalog=WrongDatabase;User ID=example;Password=synthetic-value-not-for-output" /></connectionStrings></configuration>'; Expected = 'Expected a server connection to CUS' },
    @{ Name = 'attached database'; Content = '<configuration><connectionStrings><add name="MCMConnectionString" connectionString="Data Source=unused;Initial Catalog=CUS;AttachDbFilename=C:\unused.mdf" /></connectionStrings></configuration>'; Expected = 'Expected a server connection to CUS' },
    @{ Name = 'malformed XML'; Content = '<configuration>synthetic-value-not-for-output'; Expected = 'Configuration could not be read' },
    @{ Name = 'external setting'; Content = '<configuration><connectionStrings configSource="connections.config" /></configuration>'; Expected = 'absent or stored externally/encrypted' },
    @{ Name = 'DTD rejected'; Content = '<!DOCTYPE configuration [<!ENTITY example "synthetic-value-not-for-output">]><configuration>&example;</configuration>'; Expected = 'Configuration could not be read' }
)

try {
    foreach ($case in $cases) {
        if ($null -ne $case.Content) {
            [System.IO.File]::WriteAllText($configPath, $case.Content)
        }
        $start = New-Object System.Diagnostics.ProcessStartInfo
        $start.FileName = $shell
        $start.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
            $probe + '" -WebConfigPath "' + $configPath + '"'
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $process = [System.Diagnostics.Process]::Start($start)
        try {
            $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            if ($process.ExitCode -ne 1 -or
                -not $output.Contains($case.Expected) -or
                $output.Contains($sentinel) -or $output.Contains('PASS:')) {
                throw "Failed safe-output assertion: $($case.Name)"
            }
        }
        finally {
            $process.Dispose()
        }
        Write-Output "PASS: $($case.Name)"
        if (Test-Path -LiteralPath $configPath) {
            Remove-Item -LiteralPath $configPath
        }
    }
}
finally {
    if (Test-Path -LiteralPath $configPath) {
        Remove-Item -LiteralPath $configPath
    }
    Remove-Item -LiteralPath $testDirectory
}
