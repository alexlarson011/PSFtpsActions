<#
.SYNOPSIS
Lists files and directories from an explicit FTPS endpoint.

.DESCRIPTION
Connects to an FTPS server using the bundled WinSCP .NET assembly, optionally sends a SITE command, and lists items in a remote directory. Supports standard FTP paths and MVS dataset-prefix navigation.

.PARAMETER Username
FTPS username. Use with Password, or use Credential/CredentialName instead.

.PARAMETER Password
FTPS password. Use with Username, or use Credential/CredentialName instead.

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

.PARAMETER Filter
Wildcard filter applied to returned item names. Defaults to *.

.PARAMETER Name
Returns only item names.

.PARAMETER File
Returns only files.

.PARAMETER Directory
Returns only directories.

.PARAMETER SiteCommand
Optional SITE command to send after connecting and before listing.

.PARAMETER MvsMode
Uses MVS dataset-prefix navigation before listing the current prefix.

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
Number of additional retry attempts for connection and listing actions. Defaults to the module connection default.

.PARAMETER RetryDelaySeconds
Delay between retry attempts in seconds. Defaults to the module connection default.

.EXAMPLE
Get-FtpsChildItem -HostAddress 'ftps.example.com' -CredentialName 'partner-ftps' -HostDirectory '/outbound'

Lists items in /outbound.

.EXAMPLE
Get-FtpsChildItem -HostAddress 'mvs.example.com' -CredentialName 'mainframe' -HostDirectory 'HLQ.APP.DATA' -MvsMode -Filter 'T*'

Changes to the MVS dataset prefix and lists matching items.
#>
function Get-FtpsChildItem {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param (
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
        [string]$Filter = '*',

        [Parameter(Mandatory = $false)]
        [switch]$Name,

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [switch]$File,

        [Parameter(Mandatory = $false, ParameterSetName = 'Directory')]
        [switch]$Directory,

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

    $operationName = 'Get-FtpsChildItem'
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

        if ($MvsMode) {
            $mvsDatasetPrefix = Normalize-MvsDatasetPrefix -DatasetPrefix $HostDirectory

            Write-Host "Changing to MVS dataset prefix:"
            Write-Host $mvsDatasetPrefix

            $cwdResult = Invoke-FtpsRetry `
                -RetryCount $connectionSettings.RetryCount `
                -RetryDelaySeconds $connectionSettings.RetryDelaySeconds `
                -OperationName 'Change to MVS dataset prefix' `
                -ScriptBlock { $session.ExecuteCommand("CWD $mvsDatasetPrefix") }

            if (-not [string]::IsNullOrWhiteSpace($cwdResult.Output)) {
                Write-Host "CWD output:"
                Write-Host $cwdResult.Output
            }

            if ($cwdResult.ExitCode -ne 0) {
                throw "MVS CWD failed. ExitCode=$($cwdResult.ExitCode). Output: $($cwdResult.Output)"
            }

            $listPath = '.'
        }
        else {
            $listPath = Normalize-RemoteDirectory -Directory $HostDirectory
        }

        Write-Host "Listing remote path:"
        Write-Host $listPath

        $directoryInfo = Invoke-FtpsRetry `
            -RetryCount $connectionSettings.RetryCount `
            -RetryDelaySeconds $connectionSettings.RetryDelaySeconds `
            -OperationName 'List remote directory' `
            -ScriptBlock { $session.ListDirectory($listPath) }

        foreach ($item in $directoryInfo.Files) {
            if ($item.Name -in @('.', '..')) {
                continue
            }

            if ($item.Name -notlike $Filter) {
                continue
            }

            if ($File -and $item.IsDirectory) {
                continue
            }

            if ($Directory -and -not $item.IsDirectory) {
                continue
            }

            if ($Name) {
                $item.Name
            }
            else {
                [PSCustomObject]@{
                    Name          = $item.Name
                    RemotePath    = $item.FullName
                    Length        = $item.Length
                    LastWriteTime = $item.LastWriteTime
                    IsDirectory   = $item.IsDirectory
                    HostDirectory = $HostDirectory
                    MvsMode       = [bool]$MvsMode
                }
            }
        }
    }
    catch {
        throw "FTPS child item listing failed. $($_.Exception.Message)"
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
