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

    $utf16UploadPath = Join-Path $localDir 'utf16-upload.txt'
    $utf8DownloadPath = Join-Path $downloadDir 'utf8-downloaded.txt'
    [System.IO.File]::WriteAllText($utf16UploadPath, "UTF-8 without BOM upload test   `r`nSecond line`t  `r`n", [System.Text.Encoding]::Unicode)

    $originalBytes = [System.IO.File]::ReadAllBytes($utf16UploadPath)
    Assert-True `
        -Condition ($originalBytes.Length -ge 2 -and $originalBytes[0] -eq 0xff -and $originalBytes[1] -eq 0xfe) `
        -Message 'UTF-16 source file did not contain the expected BOM before upload.'

    Send-FtpsFile `
        -FilePath $utf16UploadPath `
        -RemoteFileName 'utf8-upload.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint `
        -ConvertToUtf8NoBom `
        -TrimTrailingWhitespace `
        -LineEnding Unix

    Get-FtpsFile `
        -RemoteFileName 'utf8-upload.txt' `
        -LocalDirectory $downloadDir `
        -LocalFileName 'utf8-downloaded.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

    $downloadedBytes = [System.IO.File]::ReadAllBytes($utf8DownloadPath)
    Assert-True `
        -Condition (-not ($downloadedBytes.Length -ge 3 -and $downloadedBytes[0] -eq 0xef -and $downloadedBytes[1] -eq 0xbb -and $downloadedBytes[2] -eq 0xbf)) `
        -Message 'Downloaded converted file contains a UTF-8 BOM.'
    Assert-True `
        -Condition (-not ([System.Text.Encoding]::UTF8.GetString($downloadedBytes).Contains("`r"))) `
        -Message 'Downloaded converted file contains Windows CRLF line endings.'
    Assert-True `
        -Condition ([System.IO.File]::ReadAllText($utf8DownloadPath, [System.Text.Encoding]::UTF8) -eq "UTF-8 without BOM upload test`nSecond line`n") `
        -Message 'Downloaded converted file content did not match expected UTF-8 text.'

    Remove-FtpsFile `
        -RemoteFileName 'utf8-upload.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

    $preserveUploadPath = Join-Path $localDir 'preserve-upload.txt'
    $preserveDownloadPath = Join-Path $downloadDir 'preserve-downloaded.txt'
    [System.IO.File]::WriteAllText($preserveUploadPath, "Default preserve line ending test   `nSecond line`t  `n", [System.Text.Encoding]::Unicode)

    Send-FtpsFile `
        -FilePath $preserveUploadPath `
        -RemoteFileName 'preserve-upload.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint `
        -ConvertToUtf8NoBom `
        -TrimTrailingWhitespace

    Get-FtpsFile `
        -RemoteFileName 'preserve-upload.txt' `
        -LocalDirectory $downloadDir `
        -LocalFileName 'preserve-downloaded.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

    $preserveBytes = [System.IO.File]::ReadAllBytes($preserveDownloadPath)
    Assert-True `
        -Condition (-not ($preserveBytes.Length -ge 3 -and $preserveBytes[0] -eq 0xef -and $preserveBytes[1] -eq 0xbb -and $preserveBytes[2] -eq 0xbf)) `
        -Message 'Downloaded default preserve converted file contains a UTF-8 BOM.'
    Assert-True `
        -Condition (-not ([System.Text.Encoding]::UTF8.GetString($preserveBytes).Contains("`r"))) `
        -Message 'Downloaded default preserve converted file unexpectedly contains CR line endings.'
    Assert-True `
        -Condition ([System.IO.File]::ReadAllText($preserveDownloadPath, [System.Text.Encoding]::UTF8) -eq "Default preserve line ending test`nSecond line`n") `
        -Message 'Downloaded default preserve converted file content did not match expected LF text.'

    Remove-FtpsFile `
        -RemoteFileName 'preserve-upload.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

    $windowsUploadPath = Join-Path $localDir 'windows-upload.txt'
    $windowsDownloadPath = Join-Path $downloadDir 'windows-downloaded.txt'
    [System.IO.File]::WriteAllText($windowsUploadPath, "Explicit Windows line ending test   `nSecond line`t  `n", [System.Text.Encoding]::Unicode)

    Send-FtpsFile `
        -FilePath $windowsUploadPath `
        -RemoteFileName 'windows-upload.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint `
        -ConvertToUtf8NoBom `
        -TrimTrailingWhitespace `
        -LineEnding Windows

    Get-FtpsFile `
        -RemoteFileName 'windows-upload.txt' `
        -LocalDirectory $downloadDir `
        -LocalFileName 'windows-downloaded.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

    $windowsBytes = [System.IO.File]::ReadAllBytes($windowsDownloadPath)
    Assert-True `
        -Condition (-not ($windowsBytes.Length -ge 3 -and $windowsBytes[0] -eq 0xef -and $windowsBytes[1] -eq 0xbb -and $windowsBytes[2] -eq 0xbf)) `
        -Message 'Downloaded explicit Windows converted file contains a UTF-8 BOM.'
    Assert-True `
        -Condition ([System.Text.Encoding]::UTF8.GetString($windowsBytes).Contains("`r`n")) `
        -Message 'Downloaded explicit Windows converted file does not contain CRLF line endings.'
    Assert-True `
        -Condition ([System.IO.File]::ReadAllText($windowsDownloadPath, [System.Text.Encoding]::UTF8) -eq "Explicit Windows line ending test`r`nSecond line`r`n") `
        -Message 'Downloaded explicit Windows converted file content did not match expected CRLF text.'

    Remove-FtpsFile `
        -RemoteFileName 'windows-upload.txt' `
        -Username $server.username `
        -Password $server.password `
        -HostAddress $server.host `
        -Port $server.port `
        -HostDirectory '/' `
        -TlsMode Default `
        -TlsHostCertificateFingerprint $scanned.Fingerprint

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
