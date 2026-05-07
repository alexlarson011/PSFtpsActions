<#
.SYNOPSIS
Removes a named credential from the module credential store.

.DESCRIPTION
Deletes a named credential from the module's in-memory credential store for the current PowerShell session.

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
}
