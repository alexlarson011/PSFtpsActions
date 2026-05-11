<#
.SYNOPSIS
Stores a named PSCredential.

.DESCRIPTION
Adds or replaces a named PSCredential in the module credential store and saves it to the configured local credential store path.

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
    Save-PSFtpsCredential -Name $Name -Credential $Credential

    [PSCustomObject]@{
        Name     = $Name
        Username = $Credential.UserName
        Path     = Get-PSFtpsCredentialFilePath -Name $Name
    }
}
