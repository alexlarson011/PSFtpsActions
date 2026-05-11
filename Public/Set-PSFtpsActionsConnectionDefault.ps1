<#
.SYNOPSIS
Sets module default FTPS connection settings.

.DESCRIPTION
Updates the timeout and retry defaults used by module commands when TimeoutSeconds, RetryCount, or RetryDelaySeconds are omitted. Defaults are saved to the configured local config path.

.PARAMETER TimeoutSeconds
Default WinSCP timeout in seconds. Defaults to 30 in a fresh module session.

.PARAMETER RetryCount
Default number of additional retry attempts after the first attempt. Defaults to 0 in a fresh module session.

.PARAMETER RetryDelaySeconds
Default delay between retry attempts in seconds. Defaults to 5 in a fresh module session.
#>
function Set-PSFtpsActionsConnectionDefault {
    [CmdletBinding()]
    param (
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

    if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
        $script:PSFtpsActionsConnectionDefault.TimeoutSeconds = $TimeoutSeconds
    }

    if ($PSBoundParameters.ContainsKey('RetryCount')) {
        $script:PSFtpsActionsConnectionDefault.RetryCount = $RetryCount
    }

    if ($PSBoundParameters.ContainsKey('RetryDelaySeconds')) {
        $script:PSFtpsActionsConnectionDefault.RetryDelaySeconds = $RetryDelaySeconds
    }

    Save-PSFtpsActionsConfig

    Get-PSFtpsActionsConnectionDefault
}
