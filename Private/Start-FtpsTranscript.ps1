<#
.SYNOPSIS
Starts a transcript log for an FTPS operation.

.DESCRIPTION
Creates the requested log directory when needed, starts a timestamped PowerShell transcript, writes the transcript path, and returns the log path.
#>
function Start-FtpsTranscript {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$LogDirectory,

        [Parameter(Mandatory = $true)]
        [string]$OperationName
    )

    if ([string]::IsNullOrWhiteSpace($LogDirectory)) {
        return $null
    }

    if (-not (Test-Path -LiteralPath $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $transcriptLogPath = Join-Path $LogDirectory "$OperationName`_$timestamp.log"

    Start-Transcript -Path $transcriptLogPath -Append | Out-Null

    Write-Host "Transcript log: $transcriptLogPath"

    return $transcriptLogPath
}
