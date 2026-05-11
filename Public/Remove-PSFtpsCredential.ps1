<#
.SYNOPSIS
Removes a named credential from the module credential store.

.DESCRIPTION
Deletes a named credential from the module credential store and removes its local credential file when present.

.PARAMETER Name
Name of the credential to remove.
#>
function Remove-PSFtpsCredential {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if (-not $script:PSFtpsActionsCredentialStore.ContainsKey($Name)) {
        throw "No PSFtpsActions credential named '$Name' was found."
    }

    $script:PSFtpsActionsCredentialStore.Remove($Name)

    $credentialPath = Get-PSFtpsCredentialFilePath -Name $Name
    if (Test-Path -LiteralPath $credentialPath) {
        Remove-Item -LiteralPath $credentialPath -Force
    }
}
