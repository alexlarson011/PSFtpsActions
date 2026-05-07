<#
.SYNOPSIS
Tests an explicit FTPS connection and optional remote location.

.DESCRIPTION
Opens an FTPS session using the bundled WinSCP .NET assembly, optionally sends a SITE command, and optionally validates a host directory or MVS dataset prefix. Returns a structured object with success status and connection details instead of throwing for connection test failures.

.PARAMETER Username
FTPS username.

.PARAMETER Password
FTPS password.

.PARAMETER HostAddress
FTPS server host name or IP address.

.PARAMETER Port
FTPS server port. Defaults to 21.

.PARAMETER HostDirectory
Optional remote directory or MVS dataset prefix to validate after connecting.

.PARAMETER SiteCommand
Optional SITE command to send after connecting.

.PARAMETER MvsMode
Treats HostDirectory as an MVS dataset prefix and validates it with CWD.

.PARAMETER WinScpDllPath
Path to WinSCPnet.dll. Defaults to the bundled assembly under the module's lib folder.

.PARAMETER LogDirectory
Optional directory for PowerShell transcript logs.

.PARAMETER EnableSessionLog
Enables a WinSCP session log. Uses LogDirectory when provided, otherwise the temp directory.

.PARAMETER TlsMode
Controls WinSCP TLS raw settings. Defaults to Tls12Only.

.PARAMETER TlsHostCertificateFingerprint
Optional TLS host certificate fingerprint to validate the FTPS server certificate.

.EXAMPLE
Test-FtpsConnection -Username 'user' -Password 'pass' -HostAddress 'ftps.example.com'

Tests whether the server accepts an explicit FTPS connection.

.EXAMPLE
Test-FtpsConnection -Username 'user' -Password 'pass' -HostAddress 'mvs.example.com' -HostDirectory 'HLQ.APP.DATA' -MvsMode

Tests the connection and validates the MVS dataset prefix.
#>
function Test-FtpsConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [string]$HostAddress,

        [Parameter(Mandatory = $false)]
        [int]$Port = 21,

        [Parameter(Mandatory = $false)]
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
        [string]$TlsMode = 'Tls12Only',

        [Parameter(Mandatory = $false)]
        [string]$TlsHostCertificateFingerprint
    )

    $operationName = 'Test-FtpsConnection'
    $transcriptStarted = $false
    $session = $null

    try {
        if (-not [string]::IsNullOrWhiteSpace($LogDirectory)) {
            Start-FtpsTranscript -LogDirectory $LogDirectory -OperationName $operationName | Out-Null
            $transcriptStarted = $true
        }

        Import-WinScpAssembly -WinScpDllPath $WinScpDllPath

        $sessionOptions = New-FtpsSessionOptions `
            -HostAddress $HostAddress `
            -Port $Port `
            -Username $Username `
            -Password $Password `
            -TlsMode $TlsMode `
            -TlsHostCertificateFingerprint $TlsHostCertificateFingerprint

        $session = New-FtpsSession `
            -LogDirectory $LogDirectory `
            -EnableSessionLog:$EnableSessionLog `
            -OperationName $operationName

        Write-Host "Testing explicit FTPS connection..."
        Write-Host "Host: $HostAddress"
        Write-Host "Port: $Port"
        Write-Host "User: $Username"

        $session.Open($sessionOptions)

        Write-Host "Connection opened successfully."

        Invoke-FtpsSiteCommand `
            -Session $session `
            -SiteCommand $SiteCommand

        if (-not [string]::IsNullOrWhiteSpace($HostDirectory)) {
            if ($MvsMode) {
                $mvsDatasetPrefix = Normalize-MvsDatasetPrefix -DatasetPrefix $HostDirectory

                Write-Host "Testing MVS dataset prefix:"
                Write-Host $mvsDatasetPrefix

                $cwdResult = $session.ExecuteCommand("CWD $mvsDatasetPrefix")

                if (-not [string]::IsNullOrWhiteSpace($cwdResult.Output)) {
                    Write-Host "CWD output:"
                    Write-Host $cwdResult.Output
                }

                if ($cwdResult.ExitCode -ne 0) {
                    throw "MVS CWD failed. ExitCode=$($cwdResult.ExitCode). Output: $($cwdResult.Output)"
                }
            }
            else {
                $normalizedDirectory = Normalize-RemoteDirectory -Directory $HostDirectory

                Write-Host "Testing remote directory:"
                Write-Host $normalizedDirectory

                $session.ListDirectory($normalizedDirectory) | Out-Null
            }
        }

        Write-Host "FTPS connection test succeeded."

        [PSCustomObject]@{
            Success       = $true
            HostAddress   = $HostAddress
            Port          = $Port
            Username      = $Username
            HostDirectory = $HostDirectory
            MvsMode       = [bool]$MvsMode
            Message       = 'Connection test succeeded.'
        }
    }
    catch {
        [PSCustomObject]@{
            Success       = $false
            HostAddress   = $HostAddress
            Port          = $Port
            Username      = $Username
            HostDirectory = $HostDirectory
            MvsMode       = [bool]$MvsMode
            Message       = $_.Exception.Message
        }
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
