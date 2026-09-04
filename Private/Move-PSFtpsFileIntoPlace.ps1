<#
.SYNOPSIS
Moves a completed temporary file into its final path with rollback support.

.DESCRIPTION
Keeps the temporary file in the destination directory, renames an existing destination to a backup, and restores that backup if committing the new file fails. This provides a PowerShell 5.1-compatible replacement strategy on file systems where File.Replace is unavailable.
#>
function Move-PSFtpsFileIntoPlace {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TemporaryPath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $temporaryFullPath = [System.IO.Path]::GetFullPath($TemporaryPath)
    $destinationFullPath = [System.IO.Path]::GetFullPath($DestinationPath)
    $destinationDirectory = [System.IO.Path]::GetDirectoryName($destinationFullPath)
    $temporaryDirectory = [System.IO.Path]::GetDirectoryName($temporaryFullPath)

    if (-not $temporaryDirectory.Equals($destinationDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'TemporaryPath and DestinationPath must be in the same directory.'
    }

    if (-not [System.IO.File]::Exists($temporaryFullPath)) {
        throw "Completed temporary file not found: $temporaryFullPath"
    }

    $backupPath = Join-Path $destinationDirectory ('.{0}.{1}.rollback' -f [System.IO.Path]::GetFileName($destinationFullPath), [guid]::NewGuid().ToString('N'))
    $destinationWasMoved = $false
    $commitSucceeded = $false

    try {
        if ([System.IO.File]::Exists($destinationFullPath)) {
            [System.IO.File]::Move($destinationFullPath, $backupPath)
            $destinationWasMoved = $true
        }

        try {
            [System.IO.File]::Move($temporaryFullPath, $destinationFullPath)
            $commitSucceeded = $true
        }
        catch {
            if ($destinationWasMoved -and -not [System.IO.File]::Exists($destinationFullPath)) {
                try {
                    [System.IO.File]::Move($backupPath, $destinationFullPath)
                    $destinationWasMoved = $false
                }
                catch {
                    throw "Failed to commit '$destinationFullPath' and failed to restore its prior contents. Recovery file: '$backupPath'. $($_.Exception.Message)"
                }
            }

            throw
        }
    }
    finally {
        if ($commitSucceeded -and $destinationWasMoved -and [System.IO.File]::Exists($backupPath)) {
            try {
                [System.IO.File]::Delete($backupPath)
            }
            catch {
                Write-Warning "The new file was committed, but its rollback file could not be removed: '$backupPath'. $($_.Exception.Message)"
            }
        }
    }
}
