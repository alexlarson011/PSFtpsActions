<#
.SYNOPSIS
Runs an optional SITE command on an open WinSCP session.

.DESCRIPTION
Skips empty commands, writes any command output to the host, and throws when the server returns a non-zero exit code.
#>
function Invoke-FtpsSiteCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Session,

        [Parameter(Mandatory = $false)]
        [string]$SiteCommand
    )

    if ([string]::IsNullOrWhiteSpace($SiteCommand)) {
        return
    }

    Write-Host "Sending SITE command:"
    Write-Host $SiteCommand

    $siteResult = $Session.ExecuteCommand($SiteCommand)

    if (-not [string]::IsNullOrWhiteSpace($siteResult.Output)) {
        Write-Host "SITE command output:"
        Write-Host $siteResult.Output
    }

    if ($siteResult.ExitCode -ne 0) {
        throw "SITE command failed. ExitCode=$($siteResult.ExitCode). Output: $($siteResult.Output)"
    }
}
