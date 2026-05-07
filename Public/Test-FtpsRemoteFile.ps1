<#
.SYNOPSIS
Checks whether a remote FTPS file exists.

.DESCRIPTION
Connects to an FTPS server using the bundled WinSCP .NET assembly, optionally sends a SITE command, resolves the remote location, and returns file metadata when the target exists. Returns Exists = false when the target file is not found.

.PARAMETER RemoteFileName
Name of the remote file or MVS member/data set name to check.

.PARAMETER Username
FTPS username.

.PARAMETER Password
FTPS password.

.PARAMETER HostAddress
FTPS server host name or IP address.

.PARAMETER Port
FTPS server port. Defaults to 21.

.PARAMETER HostDirectory
Remote directory for standard FTPS paths, or MVS dataset prefix when MvsMode is used.

.PARAMETER SiteCommand
Optional SITE command to send after connecting and before the file check.

.PARAMETER MvsMode
Uses MVS dataset-prefix navigation instead of standard FTP path concatenation.

.PARAMETER WinScpDllPath
Path to WinSCPnet.dll. Defaults to the bundled assembly under the module's lib folder.

.PARAMETER LogDirectory
Optional directory for PowerShell transcript logs.

.PARAMETER EnableSessionLog
Enables a WinSCP session log. Uses LogDirectory when provided, otherwise the temp directory.

.PARAMETER TlsMode
Controls WinSCP TLS raw settings. Defaults to the module security default.

.PARAMETER TlsHostCertificateFingerprint
Optional TLS host certificate fingerprint to validate the FTPS server certificate. Values pasted from WinSCP logs or certificate thumbprints are normalized before being passed to WinSCP.

.PARAMETER TimeoutSeconds
WinSCP timeout in seconds. Defaults to the module connection default.

.PARAMETER RetryCount
Number of additional retry attempts for connection and remote-file check actions. Defaults to the module connection default.

.PARAMETER RetryDelaySeconds
Delay between retry attempts in seconds. Defaults to the module connection default.

.EXAMPLE
Test-FtpsRemoteFile -RemoteFileName 'ready.txt' -Username 'user' -Password 'pass' -HostAddress 'ftps.example.com' -HostDirectory '/outbound'

Returns metadata for /outbound/ready.txt when it exists.
#>
function Test-FtpsRemoteFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RemoteFileName,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [string]$HostAddress,

        [Parameter(Mandatory = $false)]
        [int]$Port = 21,

        [Parameter(Mandatory = $true)]
        [string]$HostDirectory,

        [Parameter(Mandatory = $false)]
        [string]$SiteCommand,

        [Parameter(Mandatory = $false)]
        [switch]$MvsMode,

        [Parameter(Mandatory = $false)]
        [string]$WinScpDllPath = $script:DefaultWinScpDllPath,

        [Parameter(Mandatory = $false)]
        [string]$LogDirectory,

        [Parameter(Mandatory = $false)]
        [switch]$EnableSessionLog,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Default', 'Tls12Only', 'Tls12OrHigher')]
        [string]$TlsMode,

        [Parameter(Mandatory = $false)]
        [string]$TlsHostCertificateFingerprint,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$RetryCount,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 86400)]
        [int]$RetryDelaySeconds
    )

    $operationName = 'Test-FtpsRemoteFile'
    $transcriptStarted = $false
    $session = $null

    try {
        if (-not [string]::IsNullOrWhiteSpace($LogDirectory)) {
            Start-FtpsTranscript -LogDirectory $LogDirectory -OperationName $operationName | Out-Null
            $transcriptStarted = $true
        }

        Import-WinScpAssembly -WinScpDllPath $WinScpDllPath

        $securitySettings = Resolve-FtpsSecuritySettings `
            -BoundParameters $PSBoundParameters `
            -TlsMode $TlsMode `
            -TlsHostCertificateFingerprint $TlsHostCertificateFingerprint

        $connectionSettings = Resolve-FtpsConnectionSettings `
            -BoundParameters $PSBoundParameters `
            -TimeoutSeconds $TimeoutSeconds `
            -RetryCount $RetryCount `
            -RetryDelaySeconds $RetryDelaySeconds

        $sessionOptions = New-FtpsSessionOptions `
            -HostAddress $HostAddress `
            -Port $Port `
            -Username $Username `
            -Password $Password `
            -TlsMode $securitySettings.TlsMode `
            -TlsHostCertificateFingerprint $securitySettings.TlsHostCertificateFingerprint `
            -TimeoutSeconds $connectionSettings.TimeoutSeconds

        $session = New-FtpsSession `
            -LogDirectory $LogDirectory `
            -EnableSessionLog:$EnableSessionLog `
            -OperationName $operationName `
            -TimeoutSeconds $connectionSettings.TimeoutSeconds

        Write-Host "Connecting to $HostAddress on port $Port using explicit FTPS..."
        Invoke-FtpsRetry `
            -RetryCount $connectionSettings.RetryCount `
            -RetryDelaySeconds $connectionSettings.RetryDelaySeconds `
            -OperationName 'Open FTPS session' `
            -ScriptBlock { $session.Open($sessionOptions) } | Out-Null

        Invoke-FtpsSiteCommand `
            -Session $session `
            -SiteCommand $SiteCommand

        $remotePath = Set-FtpsRemoteLocation `
            -Session $session `
            -HostDirectory $HostDirectory `
            -RemoteFileName $RemoteFileName `
            -MvsMode:$MvsMode

        Write-Host "Checking remote file:"
        Write-Host $remotePath

        try {
            $fileInfo = Invoke-FtpsRetry `
                -RetryCount $connectionSettings.RetryCount `
                -RetryDelaySeconds $connectionSettings.RetryDelaySeconds `
                -OperationName 'Check remote file' `
                -ScriptBlock { $session.GetFileInfo($remotePath) }

            [PSCustomObject]@{
                Exists         = $true
                RemoteFileName = $RemoteFileName
                RemotePath     = $remotePath
                Length         = $fileInfo.Length
                LastWriteTime  = $fileInfo.LastWriteTime
                IsDirectory    = $fileInfo.IsDirectory
                MvsMode        = [bool]$MvsMode
            }
        }
        catch {
            [PSCustomObject]@{
                Exists         = $false
                RemoteFileName = $RemoteFileName
                RemotePath     = $remotePath
                Length         = $null
                LastWriteTime  = $null
                IsDirectory    = $null
                MvsMode        = [bool]$MvsMode
            }
        }
    }
    catch {
        throw "FTPS remote file check failed. $($_.Exception.Message)"
    }
    finally {
        if ($session) {
            $session.Dispose()
        }

        if ($transcriptStarted) {
            Stop-Transcript | Out-Null
        }
    }
}
