<#
.SYNOPSIS
Loads module configuration from disk.

.DESCRIPTION
Reads security and connection defaults from the configured JSON config path when it exists.
#>
function Load-PSFtpsActionsConfig {
    [CmdletBinding()]
    param ()

    if (-not (Test-Path -LiteralPath $script:PSFtpsActionsConfigPath)) {
        return
    }

    $config = Get-Content -LiteralPath $script:PSFtpsActionsConfigPath -Raw | ConvertFrom-Json

    if ($config.SecurityDefault) {
        if ($config.SecurityDefault.TlsMode) {
            $script:PSFtpsActionsSecurityDefault.TlsMode = [string]$config.SecurityDefault.TlsMode
        }

        $script:PSFtpsActionsSecurityDefault.TlsHostCertificateFingerprint = $config.SecurityDefault.TlsHostCertificateFingerprint
    }

    if ($config.ConnectionDefault) {
        if ($null -ne $config.ConnectionDefault.TimeoutSeconds) {
            $script:PSFtpsActionsConnectionDefault.TimeoutSeconds = [int]$config.ConnectionDefault.TimeoutSeconds
        }

        if ($null -ne $config.ConnectionDefault.RetryCount) {
            $script:PSFtpsActionsConnectionDefault.RetryCount = [int]$config.ConnectionDefault.RetryCount
        }

        if ($null -ne $config.ConnectionDefault.RetryDelaySeconds) {
            $script:PSFtpsActionsConnectionDefault.RetryDelaySeconds = [int]$config.ConnectionDefault.RetryDelaySeconds
        }
    }
}
