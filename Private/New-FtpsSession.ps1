<#
.SYNOPSIS
Creates a WinSCP session for an FTPS operation.

.DESCRIPTION
Creates a WinSCP.Session object and, when requested, configures a WinSCP session log in the provided log directory or in the temp directory.
#>
function New-FtpsSession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$LogDirectory,

        [Parameter(Mandatory = $false)]
        [switch]$EnableSessionLog,

        [Parameter(Mandatory = $true)]
        [string]$OperationName
    )

    $session = New-Object WinSCP.Session

    if ($EnableSessionLog) {
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

        if (-not [string]::IsNullOrWhiteSpace($LogDirectory)) {
            if (-not (Test-Path -LiteralPath $LogDirectory)) {
                New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
            }

            $session.SessionLogPath = Join-Path $LogDirectory "$OperationName`_WinSCP_$timestamp.log"
        }
        else {
            $session.SessionLogPath = Join-Path $env:TEMP "$OperationName`_WinSCP_$timestamp.log"
        }

        Write-Host "WinSCP session log: $($session.SessionLogPath)"
    }

    return $session
}
