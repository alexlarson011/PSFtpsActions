[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$Python = 'python'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$serverScript = Join-Path $repoRoot 'scripts\Start-LocalFtpsServer.py'
$moduleManifest = Join-Path $repoRoot 'PSFtpsActions.psd1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("PSFtpsActions_LocalFtps_" + [guid]::NewGuid().ToString('N'))
$ftpRoot = Join-Path $testRoot 'ftproot'
$certDir = Join-Path $testRoot 'cert'
$readyFile = Join-Path $testRoot 'server-ready.json'
$downloadDir = Join-Path $testRoot 'downloads'
$localDir = Join-Path $testRoot 'local'
$logDir = Join-Path $testRoot 'logs'

$serverProcess = $null

function Assert-True {
    param (
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

try {
    New-Item -ItemType Directory -Path $ftpRoot, $downloadDir, $localDir, $logDir -Force | Out-Null

    $arguments = @(
        $serverScript,
        '--root', $ftpRoot,
        '--ready-file', $readyFile,
        '--cert-dir', $certDir,
        '--host', '127.0.0.1',
        '--port', '0',
        '--username', 'psftps',
        '--password', 'psftps'
    )

    $serverProcess = Start-Process `
        -FilePath $Python `
        -ArgumentList $arguments `
        -PassThru `
        -WindowStyle Hidden `
        -WorkingDirectory $repoRoot

    $deadline = (Get-Date).AddSeconds(20)
    while (-not (Test-Path -LiteralPath $readyFile)) {
        if ($serverProcess.HasExited) {
            throw "Local FTPS server exited before becoming ready. ExitCode=$($serverProcess.ExitCode)"
        }

        if ((Get-Date) -gt $deadline) {
            throw 'Timed out waiting for local FTPS server to start.'
        }

        Start-Sleep -Milliseconds 200
    }

    $server = Get-Content -LiteralPath $readyFile -Raw | ConvertFrom-Json

    Import-Module $moduleManifest -Force

    Write-Host "Local FTPS server: $($server.host):$($server.port)"

    $scanned = Get-FtpsTlsHostCertificateFingerprint `
        -HostAddress $server.host `
        -Port $server.port `
        -TlsMode Default

    Assert-True `
        -Condition ($scanned.Fingerprint -eq $server.fingerprint) `
        -Message "Scanned fingerprint did not match generated certificate. Expected '$($server.fingerprint)', got '$($scanned.Fingerprint)'."

    $connection = Test-FtpsConnection `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint `
        -LogDirectory $logDir `
        -EnableSessionLog

    Assert-True -Condition $connection.Success -Message "Connection test failed. $($connection.Message)"

    $uploadPath = Join-Path $localDir 'upload.txt'
    $downloadPath = Join-Path $downloadDir 'downloaded.txt'
    Set-Content -LiteralPath $uploadPath -Value 'PSFtpsActions local FTPS integration test' -NoNewline

    Send-FtpsFile `
        -FilePath $uploadPath `
        -RemoteFileName 'upload.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

    $remoteInfo = Test-FtpsRemoteFile `
        -RemoteFileName 'upload.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

    Assert-True -Condition $remoteInfo.Exists -Message 'Remote file was not found after upload.'

    Get-FtpsFile `
        -RemoteFileName 'upload.txt' `
        -LocalDirectory $downloadDir `
        -LocalFileName 'downloaded.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

    Assert-True -Condition (Test-Path -LiteralPath $downloadPath) -Message 'Downloaded file was not created.'
    Assert-True `
        -Condition ((Get-Content -LiteralPath $downloadPath -Raw) -eq (Get-Content -LiteralPath $uploadPath -Raw)) `
        -Message 'Downloaded content did not match uploaded content.'

    Remove-FtpsFile `
        -RemoteFileName 'upload.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

    $removedInfo = Test-FtpsRemoteFile `
        -RemoteFileName 'upload.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

    Assert-True -Condition (-not $removedInfo.Exists) -Message 'Remote file still exists after delete.'

    Write-Host 'Local FTPS integration test passed.'
}
finally {
    if ($serverProcess -and -not $serverProcess.HasExited) {
        Stop-Process -Id $serverProcess.Id -Force
        $serverProcess.WaitForExit()
    }

    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
