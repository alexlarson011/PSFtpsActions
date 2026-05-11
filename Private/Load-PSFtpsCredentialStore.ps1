<#
.SYNOPSIS
Loads stored credentials from disk.

.DESCRIPTION
Imports all CLIXML credential files from the configured credential store path into the in-memory credential store.
#>
function Load-PSFtpsCredentialStore {
    [CmdletBinding()]
    param ()

    $script:PSFtpsActionsCredentialStore = @{}

    if (-not (Test-Path -LiteralPath $script:PSFtpsActionsCredentialStorePath)) {
        return
    }

    Get-ChildItem -LiteralPath $script:PSFtpsActionsCredentialStorePath -Filter '*.credential.clixml' -File | ForEach-Object {
        try {
            $storedCredential = Import-Clixml -LiteralPath $_.FullName

            if ($storedCredential.Name -and $storedCredential.Credential) {
                $script:PSFtpsActionsCredentialStore[[string]$storedCredential.Name] = [pscredential]$storedCredential.Credential
            }
        }
        catch {
            Write-Warning "Failed to load PSFtpsActions credential from '$($_.FullName)'. $($_.Exception.Message)"
        }
    }
}
