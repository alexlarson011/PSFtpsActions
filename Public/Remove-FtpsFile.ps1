<#
.SYNOPSIS
Deletes a file from an explicit FTPS endpoint.

.DESCRIPTION
Connects to an FTPS server using the bundled WinSCP .NET assembly, optionally sends a SITE command, resolves the remote location, and removes the target file. In MVS mode, the command changes to the dataset prefix and deletes the named file with DELE.

.PARAMETER RemoteFileName
Name of the remote file or MVS member/data set name to delete.

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
Optional SITE command to send after connecting and before file operations.

.PARAMETER MvsMode
Uses MVS dataset-prefix navigation and a DELE command instead of standard FTP path removal.

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
Number of additional retry attempts for connection and delete actions. Defaults to the module connection default.

.PARAMETER RetryDelaySeconds
Delay between retry attempts in seconds. Defaults to the module connection default.

.EXAMPLE
Remove-FtpsFile -RemoteFileName 'processed.txt' -Username 'user' -Password 'pass' -HostAddress 'ftps.example.com' -HostDirectory '/archive'

Deletes /archive/processed.txt.

.EXAMPLE
Remove-FtpsFile -RemoteFileName 'REPORT.TXT' -Username 'user' -Password 'pass' -HostAddress 'mvs.example.com' -HostDirectory 'HLQ.APP.DATA' -MvsMode

Changes to the MVS dataset prefix and deletes REPORT.TXT.
#>
function Remove-FtpsFile {
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

    $operationName = 'Remove-FtpsFile'
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

        Write-Host "Deleting remote file:"
        Write-Host $remotePath

        if ($MvsMode) {
            Write-Host "Using MVS delete command:"
            Write-Host "DELE $RemoteFileName"

            $deleteResult = Invoke-FtpsRetry `
                -RetryCount $connectionSettings.RetryCount `
                -RetryDelaySeconds $connectionSettings.RetryDelaySeconds `
                -OperationName 'Delete MVS remote file' `
                -ScriptBlock { $session.ExecuteCommand("DELE $RemoteFileName") }

            if (-not [string]::IsNullOrWhiteSpace($deleteResult.Output)) {
                Write-Host "Delete output:"
                Write-Host $deleteResult.Output
            }

            if ($deleteResult.ExitCode -ne 0) {
                throw "MVS remote delete failed. ExitCode=$($deleteResult.ExitCode). Output: $($deleteResult.Output)"
            }
        }
        else {
            $removeResult = Invoke-FtpsRetry `
                -RetryCount $connectionSettings.RetryCount `
                -RetryDelaySeconds $connectionSettings.RetryDelaySeconds `
                -OperationName 'Delete remote file' `
                -ScriptBlock { $session.RemoveFiles($remotePath) }
            $removeResult.Check()
        }

        Write-Host "Remote file deleted successfully."
    }
    catch {
        throw "FTPS remote delete failed. $($_.Exception.Message)"
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
