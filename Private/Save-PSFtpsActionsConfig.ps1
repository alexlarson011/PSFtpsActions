<#
.SYNOPSIS
Saves module configuration to disk.

.DESCRIPTION
Writes security and connection defaults to the configured JSON config path.
#>
function Save-PSFtpsActionsConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [System.Collections.IDictionary]$SecurityDefault,

        [Parameter(Mandatory = $false)]
        [System.Collections.IDictionary]$ConnectionDefault
    )

    $securityDefaultToSave = $script:PSFtpsActionsSecurityDefault
    if ($PSBoundParameters.ContainsKey('SecurityDefault')) {
        $securityDefaultToSave = $SecurityDefault
    }

    $connectionDefaultToSave = $script:PSFtpsActionsConnectionDefault
    if ($PSBoundParameters.ContainsKey('ConnectionDefault')) {
        $connectionDefaultToSave = $ConnectionDefault
    }

    $configPath = [System.IO.Path]::GetFullPath($script:PSFtpsActionsConfigPath)
    $configDirectory = [System.IO.Path]::GetDirectoryName($configPath)
    if (-not (Test-Path -LiteralPath $configDirectory)) {
        New-Item -ItemType Directory -Path $configDirectory -Force -ErrorAction Stop | Out-Null
    }

    $config = [ordered]@{
        SecurityDefault = [ordered]@{
            TlsMode                        = $securityDefaultToSave.TlsMode
            TlsHostCertificateFingerprint = $securityDefaultToSave.TlsHostCertificateFingerprint
        }
        ConnectionDefault = [ordered]@{
            TimeoutSeconds    = $connectionDefaultToSave.TimeoutSeconds
            RetryCount        = $connectionDefaultToSave.RetryCount
            RetryDelaySeconds = $connectionDefaultToSave.RetryDelaySeconds
        }
    }

    $temporaryPath = Join-Path $configDirectory ('.{0}.{1}.tmp' -f [System.IO.Path]::GetFileName($configPath), [guid]::NewGuid().ToString('N'))
    try {
        $configJson = ($config | ConvertTo-Json -Depth 5) + [Environment]::NewLine
        $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($temporaryPath, $configJson, $utf8WithoutBom)

        # Verify the completed temporary file before it can replace the active configuration.
        [System.IO.File]::ReadAllText($temporaryPath) | ConvertFrom-Json -ErrorAction Stop | Out-Null

        Move-PSFtpsFileIntoPlace -TemporaryPath $temporaryPath -DestinationPath $configPath
    }
    finally {
        foreach ($cleanupPath in @($temporaryPath)) {
            if ([System.IO.File]::Exists($cleanupPath)) {
                try {
                    [System.IO.File]::Delete($cleanupPath)
                }
                catch {
                    Write-Warning "Failed to remove temporary configuration file '$cleanupPath'. $($_.Exception.Message)"
                }
            }
        }
    }
}
