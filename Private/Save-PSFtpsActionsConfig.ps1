<#
.SYNOPSIS
Saves module configuration to disk.

.DESCRIPTION
Writes security and connection defaults to the configured JSON config path.
#>
function Save-PSFtpsActionsConfig {
    [CmdletBinding()]
    param ()

    $configDirectory = Split-Path -Parent $script:PSFtpsActionsConfigPath
    if (-not [string]::IsNullOrWhiteSpace($configDirectory) -and -not (Test-Path -LiteralPath $configDirectory)) {
        New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
    }

    $config = [ordered]@{
        SecurityDefault = [ordered]@{
            TlsMode                       = $script:PSFtpsActionsSecurityDefault.TlsMode
            TlsHostCertificateFingerprint = $script:PSFtpsActionsSecurityDefault.TlsHostCertificateFingerprint
        }
        ConnectionDefault = [ordered]@{
            TimeoutSeconds    = $script:PSFtpsActionsConnectionDefault.TimeoutSeconds
            RetryCount        = $script:PSFtpsActionsConnectionDefault.RetryCount
            RetryDelaySeconds = $script:PSFtpsActionsConnectionDefault.RetryDelaySeconds
        }
    }

    $config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:PSFtpsActionsConfigPath -Encoding UTF8
}
