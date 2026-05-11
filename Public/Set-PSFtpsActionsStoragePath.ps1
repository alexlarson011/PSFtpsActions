<#
.SYNOPSIS
Sets PSFtpsActions local storage paths.

.DESCRIPTION
Changes the module's local storage paths for the current PowerShell session. Existing config and credentials are loaded from the new paths when present.

.PARAMETER StorageRoot
Root folder used for config.json and the Credentials folder.

.PARAMETER ConfigPath
Explicit path to the JSON configuration file.

.PARAMETER CredentialStorePath
Explicit path to the folder containing credential CLIXML files.
#>
function Set-PSFtpsActionsStoragePath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$StorageRoot,

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [string]$CredentialStorePath
    )

    if ($PSBoundParameters.ContainsKey('StorageRoot')) {
        if ([string]::IsNullOrWhiteSpace($StorageRoot)) {
            throw 'StorageRoot cannot be empty.'
        }

        $script:PSFtpsActionsStorageRoot = $StorageRoot
        $script:PSFtpsActionsConfigPath = Join-Path $StorageRoot 'config.json'
        $script:PSFtpsActionsCredentialStorePath = Join-Path $StorageRoot 'Credentials'
    }

    if ($PSBoundParameters.ContainsKey('ConfigPath')) {
        if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
            throw 'ConfigPath cannot be empty.'
        }

        $script:PSFtpsActionsConfigPath = $ConfigPath
    }

    if ($PSBoundParameters.ContainsKey('CredentialStorePath')) {
        if ([string]::IsNullOrWhiteSpace($CredentialStorePath)) {
            throw 'CredentialStorePath cannot be empty.'
        }

        $script:PSFtpsActionsCredentialStorePath = $CredentialStorePath
    }

    $script:PSFtpsActionsSecurityDefault = @{
        TlsMode                       = 'Default'
        TlsHostCertificateFingerprint = $null
    }
    $script:PSFtpsActionsConnectionDefault = @{
        TimeoutSeconds     = 30
        RetryCount         = 0
        RetryDelaySeconds  = 5
    }

    Load-PSFtpsActionsConfig
    Load-PSFtpsCredentialStore

    Get-PSFtpsActionsStoragePath
}
