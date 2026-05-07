<#
.SYNOPSIS
Normalizes a standard remote FTP directory path.

.DESCRIPTION
Trims whitespace and ensures the directory starts and ends with a forward slash so file names can be appended consistently.
#>
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
