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