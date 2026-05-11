<#
.SYNOPSIS
Builds the file path for a stored credential.

.DESCRIPTION
Returns the local CLIXML path for a named credential. Names are converted to file-safe names using base64url encoding.
#>
function Get-PSFtpsCredentialFilePath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Name)
    $encodedName = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')

    Join-Path $script:PSFtpsActionsCredentialStorePath "$encodedName.credential.clixml"
}
