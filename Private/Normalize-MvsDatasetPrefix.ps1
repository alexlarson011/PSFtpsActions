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