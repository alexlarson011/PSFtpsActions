<#
.SYNOPSIS
Gets PSFtpsActions local storage paths.

.DESCRIPTION
Returns the current local storage root, config path, and credential store path used by the module.
#>
function Get-PSFtpsActionsStoragePath {
    [CmdletBinding()]
    param ()

    [PSCustomObject]@{
        StorageRoot         = $script:PSFtpsActionsStorageRoot
        ConfigPath          = $script:PSFtpsActionsConfigPath
        CredentialStorePath = $script:PSFtpsActionsCredentialStorePath
    }
}
