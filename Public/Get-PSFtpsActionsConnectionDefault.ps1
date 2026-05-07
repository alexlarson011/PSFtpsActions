<#
.SYNOPSIS
Gets the module default FTPS connection settings.

.DESCRIPTION
Returns the current script-scoped timeout and retry defaults used by commands when TimeoutSeconds, RetryCount, or RetryDelaySeconds are not provided directly.
#>
function Get-PSFtpsActionsConnectionDefault {
    [CmdletBinding()]
    param ()

    [PSCustomObject]@{
        TimeoutSeconds    = $script:PSFtpsActionsConnectionDefault.TimeoutSeconds
        RetryCount        = $script:PSFtpsActionsConnectionDefault.RetryCount
        RetryDelaySeconds = $script:PSFtpsActionsConnectionDefault.RetryDelaySeconds
    }
}
