<#
.SYNOPSIS
Normalizes an MVS dataset prefix for CWD commands.

.DESCRIPTION
Trims whitespace and surrounding single quotes, ensures the prefix ends with a period, and returns the value wrapped in single quotes.
#>
function Normalize-MvsDatasetPrefix {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DatasetPrefix
    )

    $DatasetPrefix = $DatasetPrefix.Trim()
    $DatasetPrefix = $DatasetPrefix.Trim("'")

    if (-not $DatasetPrefix.EndsWith('.')) {
        $DatasetPrefix = $DatasetPrefix + '.'
    }

    return "'" + $DatasetPrefix + "'"
}
