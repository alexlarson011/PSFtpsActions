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
        [switch]$MvsMode,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$RetryCount = 0,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 86400)]
        [int]$RetryDelaySeconds = 5
    )

    if ([string]::IsNullOrWhiteSpace($RemoteFileName)) {
        throw 'RemoteFileName cannot be empty.'
    }

    if ($RemoteFileName -match '[\r\n]') {
        throw 'RemoteFileName cannot contain carriage-return or newline characters.'
    }

    if ($MvsMode) {
        $mvsDatasetPrefix = Normalize-MvsDatasetPrefix -DatasetPrefix $HostDirectory

        Write-Host "Changing to MVS dataset prefix:"
        Write-Host $mvsDatasetPrefix

        $cwdResult = Invoke-FtpsRetry `
            -RetryCount $RetryCount `
            -RetryDelaySeconds $RetryDelaySeconds `
            -OperationName 'Change to MVS dataset prefix' `
            -ScriptBlock {
                $result = $Session.ExecuteCommand("CWD $mvsDatasetPrefix")

                if ($result.ExitCode -ne 0) {
                    throw "MVS CWD failed. ExitCode=$($result.ExitCode). Output: $($result.Output)"
                }

                return $result
            }

        if (-not [string]::IsNullOrWhiteSpace($cwdResult.Output)) {
            Write-Host "CWD output:"
            Write-Host $cwdResult.Output
        }

        return $RemoteFileName
    }

    $normalizedDirectory = Normalize-RemoteDirectory -Directory $HostDirectory

    return $normalizedDirectory + $RemoteFileName
}
