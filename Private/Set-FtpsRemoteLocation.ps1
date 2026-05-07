<#
.SYNOPSIS
Resolves the remote file location for an FTPS operation.

.DESCRIPTION
For standard FTPS paths, normalizes the host directory and appends the remote file name. For MVS mode, changes the session to the normalized dataset prefix and returns the remote file name for the operation.
#>
function Set-FtpsRemoteLocation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Session,

        [Parameter(Mandatory = $true)]
        [string]$HostDirectory,

        [Parameter(Mandatory = $true)]
        [string]$RemoteFileName,

        [Parameter(Mandatory = $false)]
        [switch]$MvsMode
    )

    if ($MvsMode) {
        $mvsDatasetPrefix = Normalize-MvsDatasetPrefix -DatasetPrefix $HostDirectory

        Write-Host "Changing to MVS dataset prefix:"
        Write-Host $mvsDatasetPrefix

        $cwdResult = $Session.ExecuteCommand("CWD $mvsDatasetPrefix")

        if (-not [string]::IsNullOrWhiteSpace($cwdResult.Output)) {
            Write-Host "CWD output:"
            Write-Host $cwdResult.Output
        }

        if ($cwdResult.ExitCode -ne 0) {
            throw "MVS CWD failed. ExitCode=$($cwdResult.ExitCode). Output: $($cwdResult.Output)"
        }

        return $RemoteFileName
    }

    $normalizedDirectory = Normalize-RemoteDirectory -Directory $HostDirectory

    return $normalizedDirectory + $RemoteFileName
}
