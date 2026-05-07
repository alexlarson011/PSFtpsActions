<#
.SYNOPSIS
Stores a named PSCredential for the current module session.

.DESCRIPTION
Adds or replaces a named PSCredential in the module's in-memory credential store. The credential is not written to disk and lasts only for the current PowerShell session.

.PARAMETER Name
Name used to retrieve the credential.

.PARAMETER Credential
Credential to store.
#>
function Set-PSFtpsCredential {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [pscredential]$Credential
    )

    $script:PSFtpsActionsCredentialStore[$Name] = $Credential

    [PSCustomObject]@{
        Name     = $Name
        Username = $Credential.UserName
    }
}
