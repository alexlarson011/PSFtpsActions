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
        New-Item -ItemType Directory -Path $script:PSFtpsActionsCredentialStorePath -Force -ErrorAction Stop | Out-Null
    }

    $credentialPath = [System.IO.Path]::GetFullPath((Get-PSFtpsCredentialFilePath -Name $Name))
    $credentialDirectory = [System.IO.Path]::GetDirectoryName($credentialPath)
    $temporaryPath = Join-Path $credentialDirectory ('.{0}.{1}.tmp' -f [System.IO.Path]::GetFileName($credentialPath), [guid]::NewGuid().ToString('N'))
    try {
        [PSCustomObject]@{
            Name       = $Name
            Credential = $Credential
        } | Export-Clixml -LiteralPath $temporaryPath -ErrorAction Stop

        # Verify that the credential round-trips before replacing the active file.
        $storedCredential = Import-Clixml -LiteralPath $temporaryPath -ErrorAction Stop
        if (
            $null -eq $storedCredential -or
            [string]$storedCredential.Name -cne $Name -or
            $storedCredential.Credential -isnot [pscredential]
        ) {
            throw [System.IO.InvalidDataException]::new('Credential serialization validation failed.')
        }

        Move-PSFtpsFileIntoPlace -TemporaryPath $temporaryPath -DestinationPath $credentialPath
    }
    finally {
        foreach ($cleanupPath in @($temporaryPath)) {
            if ([System.IO.File]::Exists($cleanupPath)) {
                try {
                    [System.IO.File]::Delete($cleanupPath)
                }
                catch {
                    Write-Warning "Failed to remove temporary credential file '$cleanupPath'. $($_.Exception.Message)"
                }
            }
        }
    }
}
