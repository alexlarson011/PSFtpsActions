<#
.SYNOPSIS
Saves a named credential to disk.

.DESCRIPTION
Exports credential metadata and the PSCredential object to CLIXML. On Windows, the credential secret is protected by DPAPI for the current user.
#>
function Save-PSFtpsCredential {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [pscredential]$Credential
    )

    if (-not (Test-Path -LiteralPath $script:PSFtpsActionsCredentialStorePath)) {
        New-Item -ItemType Directory -Path $script:PSFtpsActionsCredentialStorePath -Force | Out-Null
    }

    [PSCustomObject]@{
        Name       = $Name
        Credential = $Credential
    } | Export-Clixml -LiteralPath (Get-PSFtpsCredentialFilePath -Name $Name)
}
