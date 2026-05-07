<#
.SYNOPSIS
Downloads a file from an explicit FTPS endpoint.

.DESCRIPTION
Connects to an FTPS server using the bundled WinSCP .NET assembly, optionally sends a SITE command, resolves the remote location, and downloads a file in ASCII transfer mode. Supports standard FTP paths and MVS dataset-prefix navigation. Can optionally remove the remote file after a successful download.

.PARAMETER RemoteFileName
Name of the remote file or MVS member/data set name to download.

.PARAMETER LocalDirectory
Existing local directory where the downloaded file should be saved.

.PARAMETER LocalFileName
Optional local file name. When omitted, RemoteFileName is used.

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
Uses MVS dataset-prefix navigation and file commands instead of standard FTP path concatenation.

.PARAMETER DeleteRemoteAfterDownload
Deletes the remote file after the download succeeds.

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
Get-FtpsFile -RemoteFileName 'inbound.txt' -LocalDirectory 'C:\Temp' -Username 'user' -Password 'pass' -HostAddress 'ftps.example.com' -HostDirectory '/outbound'

Downloads /outbound/inbound.txt to C:\Temp\inbound.txt.

.EXAMPLE
Get-FtpsFile -RemoteFileName 'REPORT.TXT' -LocalDirectory 'C:\Temp' -Username 'user' -Password 'pass' -HostAddress 'mvs.example.com' -HostDirectory 'HLQ.APP.DATA' -MvsMode -DeleteRemoteAfterDownload

Changes to the MVS dataset prefix and downloads REPORT.TXT, then deletes the remote file after a successful transfer.
#>
function Get-FtpsFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RemoteFileName,

        [Parameter(Mandatory = $true)]
        [string]$LocalDirectory,

        [Parameter(Mandatory = $false)]
        [string]$LocalFileName,

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
        [switch]$DeleteRemoteAfterDownload,

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

    $operationName = 'Get-FtpsFile'
    $transcriptStarted = $false
    $session = $null

    try {
        if (-not [string]::IsNullOrWhiteSpace($LogDirectory)) {
            Start-FtpsTranscript -LogDirectory $LogDirectory -OperationName $operationName | Out-Null
            $transcriptStarted = $true
        }

        if (-not (Test-Path -LiteralPath $LocalDirectory)) {
            throw "Local directory not found: $LocalDirectory"
        }

        Import-WinScpAssembly -WinScpDllPath $WinScpDllPath

        if ([string]::IsNullOrWhiteSpace($LocalFileName)) {
            $LocalFileName = $RemoteFileName
        }

        $localPath = Join-Path $LocalDirectory $LocalFileName

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

        Write-Host "Connecting to $HostAddress on port $Port using explicit FTPS..."
        $session.Open($sessionOptions)

        Invoke-FtpsSiteCommand `
            -Session $session `
            -SiteCommand $SiteCommand

        $remotePath = Set-FtpsRemoteLocation `
            -Session $session `
            -HostDirectory $HostDirectory `
            -RemoteFileName $RemoteFileName `
            -MvsMode:$MvsMode

        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Ascii

        Write-Host "Downloading file..."
        Write-Host "Remote file: $remotePath"
        Write-Host "Local file : $localPath"
        Write-Host "Mode       : ASCII"
        Write-Host "MVS mode   : $MvsMode"

        $transferResult = $session.GetFiles(
            $remotePath,
            $localPath,
            $false,
            $transferOptions
        )

        $transferResult.Check()

        foreach ($transfer in $transferResult.Transfers) {
            Write-Host "Downloaded: $($transfer.FileName)"
        }

        Write-Host "Download complete."

        if ($DeleteRemoteAfterDownload) {
            Write-Host "Deleting remote file after successful download:"
            Write-Host $remotePath

            if ($MvsMode) {
                Write-Host "Using MVS delete command:"
                Write-Host "DELE $RemoteFileName"

                $deleteResult = $session.ExecuteCommand("DELE $RemoteFileName")

                if (-not [string]::IsNullOrWhiteSpace($deleteResult.Output)) {
                    Write-Host "Delete output:"
                    Write-Host $deleteResult.Output
                }

                if ($deleteResult.ExitCode -ne 0) {
                    throw "MVS remote delete failed. ExitCode=$($deleteResult.ExitCode). Output: $($deleteResult.Output)"
                }
            }
            else {
                $removeResult = $session.RemoveFiles($remotePath)
                $removeResult.Check()
            }

            Write-Host "Remote file deleted successfully."
        }
    }
    catch {
        throw "FTPS download failed. $($_.Exception.Message)"
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
