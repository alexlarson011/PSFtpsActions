<#
.SYNOPSIS
Gets named credentials from the module credential store.

.DESCRIPTION
Returns credential metadata from the module's in-memory credential store. Use IncludeCredential to return the PSCredential object.

.PARAMETER Name
Optional credential name to retrieve. When omitted, all stored credential names are returned.

.PARAMETER IncludeCredential
Returns the PSCredential object in the output.
#>
function Get-PSFtpsCredential {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeCredential
    )

    $names = if ([string]::IsNullOrWhiteSpace($Name)) {
        $script:PSFtpsActionsCredentialStore.Keys
    }
    else {
        if (-not $script:PSFtpsActionsCredentialStore.ContainsKey($Name)) {
            throw "No PSFtpsActions credential named '$Name' was found."
        }

        @($Name)
    }

    foreach ($credentialName in ($names | Sort-Object)) {
        $credential = $script:PSFtpsActionsCredentialStore[$credentialName]

        $properties = [ordered]@{
            Name     = $credentialName
            Username = $credential.UserName
        }

        if ($IncludeCredential) {
            $properties.Credential = $credential
        }

        [PSCustomObject]$properties
    }
}
