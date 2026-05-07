<#
.SYNOPSIS
Resolves credentials for an FTPS command.

.DESCRIPTION
Returns a PSCredential from an explicit Credential parameter, a named module credential, or the legacy Username and Password parameters.
#>
function Resolve-FtpsCredential {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$BoundParameters,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [pscredential]$Credential,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$CredentialName,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Username,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Password
    )

    if ($BoundParameters.ContainsKey('Credential') -and $Credential) {
        return $Credential
    }

    if ($BoundParameters.ContainsKey('CredentialName')) {
        if ([string]::IsNullOrWhiteSpace($CredentialName)) {
            throw 'CredentialName cannot be empty.'
        }

        if (-not $script:PSFtpsActionsCredentialStore.ContainsKey($CredentialName)) {
            throw "No PSFtpsActions credential named '$CredentialName' was found."
        }

        return $script:PSFtpsActionsCredentialStore[$CredentialName]
    }

    if ([string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($Password)) {
        throw 'Provide either -Credential, -CredentialName, or both -Username and -Password.'
    }

    $securePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    return New-Object System.Management.Automation.PSCredential($Username, $securePassword)
}
