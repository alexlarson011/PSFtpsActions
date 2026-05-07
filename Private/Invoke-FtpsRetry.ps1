<#
.SYNOPSIS
Runs an FTPS action with retry handling.

.DESCRIPTION
Executes a script block and retries failures up to the requested retry count. RetryCount is the number of additional attempts after the initial attempt.
#>
function Invoke-FtpsRetry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$RetryCount = 0,

        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 86400)]
        [int]$RetryDelaySeconds = 5,

        [Parameter(Mandatory = $false)]
        [string]$OperationName = 'FTPS operation'
    )

    $attempt = 0
    $maxAttempts = $RetryCount + 1

    while ($attempt -lt $maxAttempts) {
        $attempt++

        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -ge $maxAttempts) {
                throw
            }

            Write-Host "$OperationName failed on attempt $attempt of $maxAttempts. Retrying in $RetryDelaySeconds second(s)."
            Write-Host $_.Exception.Message

            if ($RetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
}
