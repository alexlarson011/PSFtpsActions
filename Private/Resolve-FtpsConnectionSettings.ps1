<#
.SYNOPSIS
Resolves effective FTPS connection settings.

.DESCRIPTION
Combines command-level timeout and retry settings with the module connection default hashtable. Explicit command parameters win over configured defaults.
#>
function Resolve-FtpsConnectionSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$BoundParameters,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [int]$TimeoutSeconds,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [int]$RetryCount,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [int]$RetryDelaySeconds
    )

    $effectiveTimeoutSeconds = $script:PSFtpsActionsConnectionDefault.TimeoutSeconds
    $effectiveRetryCount = $script:PSFtpsActionsConnectionDefault.RetryCount
    $effectiveRetryDelaySeconds = $script:PSFtpsActionsConnectionDefault.RetryDelaySeconds

    if ($BoundParameters.ContainsKey('TimeoutSeconds')) {
        $effectiveTimeoutSeconds = $TimeoutSeconds
    }

    if ($BoundParameters.ContainsKey('RetryCount')) {
        $effectiveRetryCount = $RetryCount
    }

    if ($BoundParameters.ContainsKey('RetryDelaySeconds')) {
        $effectiveRetryDelaySeconds = $RetryDelaySeconds
    }

    [PSCustomObject]@{
        TimeoutSeconds    = $effectiveTimeoutSeconds
        RetryCount        = $effectiveRetryCount
        RetryDelaySeconds = $effectiveRetryDelaySeconds
    }
}
