function Normalize-RemoteDirectory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    $Directory = $Directory.Trim()

    if (-not $Directory.StartsWith('/')) {
        $Directory = '/' + $Directory
    }

    if (-not $Directory.EndsWith('/')) {
        $Directory = $Directory + '/'
    }

    return $Directory
}