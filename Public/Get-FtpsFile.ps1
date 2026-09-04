<#
.SYNOPSIS
Downloads a file from an explicit FTPS endpoint.

.DESCRIPTION
Connects to an FTPS server using the bundled WinSCP .NET assembly, optionally sends a SITE command, resolves the remote location, and downloads a file. Supports standard FTP paths and MVS dataset-prefix navigation. Can optionally remove the remote file after a successful download.

.PARAMETER RemoteFileName
Name of the remote file or MVS member/data set name to download.

.PARAMETER LocalDirectory
Existing local directory where the downloaded file should be saved.

.PARAMETER LocalFileName
Optional local file name. When omitted, RemoteFileName is used.

.PARAMETER Username
FTPS username. Use with Password, or use Credential/CredentialName instead.

.PARAMETER Password
Legacy plain-text FTPS password. Use with Username; prefer Credential or CredentialName when possible.

.PARAMETER Credential
PSCredential containing the FTPS username and password.

.PARAMETER CredentialName
Name of a credential stored with Set-PSFtpsCredential.

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

.PARAMETER TransferMode
WinSCP transfer mode. Ascii preserves the module's historical behavior. Binary transfers bytes unchanged. Automatic lets WinSCP choose from the file name.

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
Number of additional retry attempts for connection and transfer actions. Defaults to the module connection default.

.PARAMETER RetryDelaySeconds
Delay between retry attempts in seconds. Defaults to the module connection default.

.EXAMPLE
Get-FtpsFile -RemoteFileName 'inbound.txt' -LocalDirectory 'C:\Temp' -Username 'user' -Password 'pass' -HostAddress 'ftps.example.com' -HostDirectory '/outbound'

Downloads /outbound/inbound.txt to C:\Temp\inbound.txt.

.EXAMPLE
Get-FtpsFile -RemoteFileName 'REPORT.TXT' -LocalDirectory 'C:\Temp' -Username 'user' -Password 'pass' -HostAddress 'mvs.example.com' -HostDirectory 'HLQ.APP.DATA' -MvsMode -DeleteRemoteAfterDownload

Changes to the MVS dataset prefix and downloads REPORT.TXT, then deletes the remote file after a successful transfer.
#>
function Get-FtpsFile {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RemoteFileName,

        [Parameter(Mandatory = $true)]
        [string]$LocalDirectory,

        [Parameter(Mandatory = $false)]
        [string]$LocalFileName,

        [Parameter(Mandatory = $false)]
        [string]$Username,

        [Parameter(Mandatory = $false)]
        [string]$Password,

        [Parameter(Mandatory = $false)]
        [pscredential]$Credential,

        [Parameter(Mandatory = $false)]
        [string]$CredentialName,

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
        [ValidateSet('Ascii', 'Binary', 'Automatic')]
        [string]$TransferMode = 'Ascii',

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

    $operationName = 'Get-FtpsFile'
    $transcriptStarted = $false
    $session = $null
    $temporaryDownloadPath = $null

    try {
        if (-not (Test-Path -LiteralPath $LocalDirectory -PathType Container)) {
            throw "Local directory not found: $LocalDirectory"
        }

        if ([string]::IsNullOrWhiteSpace($LocalFileName)) {
            $LocalFileName = $RemoteFileName
        }

        if ([System.IO.Path]::IsPathRooted($LocalFileName)) {
            throw "LocalFileName must be relative to LocalDirectory: $LocalFileName"
        }

        $localDirectoryPath = (Get-Item -LiteralPath $LocalDirectory).FullName
        $trimCharacters = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $localDirectoryPrefix = $localDirectoryPath.TrimEnd($trimCharacters) + [System.IO.Path]::DirectorySeparatorChar
        $localPath = [System.IO.Path]::GetFullPath((Join-Path $localDirectoryPath $LocalFileName))

        if (-not $localPath.StartsWith($localDirectoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "LocalFileName must resolve inside LocalDirectory: $LocalFileName"
        }

        $destinationDirectory = Split-Path -Parent $localPath
        if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
            throw "Local destination directory not found: $destinationDirectory"
        }

        if (Test-Path -LiteralPath $localPath -PathType Container) {
            throw "Local destination is a directory: $localPath"
        }

        $downloadAction = "Download '$RemoteFileName' from $HostAddress using $TransferMode transfer mode"
        if ($DeleteRemoteAfterDownload) {
            $downloadAction += ' and request remote deletion after the local file is committed'
        }

        if (-not $PSCmdlet.ShouldProcess($localPath, $downloadAction)) {
            return
        }

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

        $resolvedCredential = Resolve-FtpsCredential `
            -BoundParameters $PSBoundParameters `
            -Credential $Credential `
            -CredentialName $CredentialName `
            -Username $Username `
            -Password $Password

        $sessionOptions = New-FtpsSessionOptions `
            -HostAddress $HostAddress `
            -Port $Port `
            -Credential $resolvedCredential `
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
            -MvsMode:$MvsMode `
            -RetryCount $connectionSettings.RetryCount `
            -RetryDelaySeconds $connectionSettings.RetryDelaySeconds

        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::$TransferMode
        $remoteFileMask = [WinSCP.RemotePath]::EscapeFileMask($remotePath)
        $temporaryDownloadPath = Join-Path $destinationDirectory (".PSFtpsActions.{0}.partial" -f ([guid]::NewGuid().ToString('N')))

        Write-Host "Downloading file..."
        Write-Host "Remote file: $remotePath"
        Write-Host "Local file : $localPath"
        Write-Host "Mode       : $TransferMode"
        Write-Host "MVS mode   : $MvsMode"

        $transferResult = Invoke-FtpsRetry `
            -RetryCount $connectionSettings.RetryCount `
            -RetryDelaySeconds $connectionSettings.RetryDelaySeconds `
            -OperationName 'Download FTPS file' `
            -ScriptBlock {
                if (Test-Path -LiteralPath $temporaryDownloadPath) {
                    Remove-Item -LiteralPath $temporaryDownloadPath -Force
                }

                $result = $session.GetFiles(
                    $remoteFileMask,
                    $temporaryDownloadPath,
                    $false,
                    $transferOptions
                )

                $result.Check()

                if ($result.Transfers.Count -ne 1) {
                    throw "Expected one remote file but WinSCP transferred $($result.Transfers.Count)."
                }

                return $result
            }

        foreach ($transfer in $transferResult.Transfers) {
            Write-Host "Downloaded: $($transfer.FileName)"
        }

        Move-PSFtpsFileIntoPlace -TemporaryPath $temporaryDownloadPath -DestinationPath $localPath
        $temporaryDownloadPath = $null

        Write-Host "Download complete."

        if ($DeleteRemoteAfterDownload) {
            Write-Host "Deleting remote file after successful download:"
            Write-Host $remotePath

            if (-not $PSCmdlet.ShouldProcess($remotePath, 'Delete remote file after successful download')) {
                return
            }

            if ($MvsMode) {
                Write-Host "Using MVS delete command:"
                Write-Host "DELE $RemoteFileName"

                $deleteResult = Invoke-FtpsRetry `
                    -RetryCount $connectionSettings.RetryCount `
                    -RetryDelaySeconds $connectionSettings.RetryDelaySeconds `
                    -OperationName 'Delete MVS remote file' `
                    -ScriptBlock {
                        $result = $session.ExecuteCommand("DELE $RemoteFileName")

                        if ($result.ExitCode -ne 0) {
                            throw "MVS remote delete failed. ExitCode=$($result.ExitCode). Output: $($result.Output)"
                        }

                        return $result
                    }

                if (-not [string]::IsNullOrWhiteSpace($deleteResult.Output)) {
                    Write-Host "Delete output:"
                    Write-Host $deleteResult.Output
                }

            }
            else {
                Invoke-FtpsRetry `
                    -RetryCount $connectionSettings.RetryCount `
                    -RetryDelaySeconds $connectionSettings.RetryDelaySeconds `
                    -OperationName 'Delete remote file' `
                    -ScriptBlock { $session.RemoveFile($remotePath) } | Out-Null
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

        if (-not [string]::IsNullOrWhiteSpace($temporaryDownloadPath) -and (Test-Path -LiteralPath $temporaryDownloadPath)) {
            Remove-Item -LiteralPath $temporaryDownloadPath -Force
        }
    }
}
