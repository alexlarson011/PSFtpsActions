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

    try {
        $configJson = Get-Content -LiteralPath $script:PSFtpsActionsConfigPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($configJson)) {
            throw [System.IO.InvalidDataException]::new('The configuration file is empty.')
        }

        $config = $configJson | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to load PSFtpsActions configuration from '$script:PSFtpsActionsConfigPath'. Existing defaults will be used. $($_.Exception.Message)"
        return
    }

    if ($null -eq $config -or $config -isnot [PSCustomObject]) {
        Write-Warning "Failed to load PSFtpsActions configuration from '$script:PSFtpsActionsConfigPath'. The JSON root must be an object. Existing defaults will be used."
        return
    }

    # Stage validated values so a partially malformed file cannot partially update module state.
    $loadedSecurityDefault = @{
        TlsMode                        = $script:PSFtpsActionsSecurityDefault.TlsMode
        TlsHostCertificateFingerprint = $script:PSFtpsActionsSecurityDefault.TlsHostCertificateFingerprint
    }
    $loadedConnectionDefault = @{
        TimeoutSeconds    = $script:PSFtpsActionsConnectionDefault.TimeoutSeconds
        RetryCount        = $script:PSFtpsActionsConnectionDefault.RetryCount
        RetryDelaySeconds = $script:PSFtpsActionsConnectionDefault.RetryDelaySeconds
    }

    $securityProperty = $config.PSObject.Properties['SecurityDefault']
    if ($null -ne $securityProperty -and $null -ne $securityProperty.Value) {
        $securityDefault = $securityProperty.Value

        if ($securityDefault -is [PSCustomObject]) {
            $tlsModeProperty = $securityDefault.PSObject.Properties['TlsMode']
            if ($null -ne $tlsModeProperty) {
                $validTlsModes = @('Default', 'Tls12Only', 'Tls12OrHigher')
                if ($tlsModeProperty.Value -is [string] -and $validTlsModes -contains $tlsModeProperty.Value) {
                    $loadedSecurityDefault.TlsMode = [string]$tlsModeProperty.Value
                }
                else {
                    Write-Warning "Ignoring invalid SecurityDefault.TlsMode in '$script:PSFtpsActionsConfigPath'. Expected Default, Tls12Only, or Tls12OrHigher."
                }
            }

            $fingerprintProperty = $securityDefault.PSObject.Properties['TlsHostCertificateFingerprint']
            if ($null -ne $fingerprintProperty) {
                if ($null -eq $fingerprintProperty.Value -or $fingerprintProperty.Value -is [string]) {
                    $loadedSecurityDefault.TlsHostCertificateFingerprint = Normalize-TlsHostCertificateFingerprint -Fingerprint $fingerprintProperty.Value
                }
                else {
                    Write-Warning "Ignoring invalid SecurityDefault.TlsHostCertificateFingerprint in '$script:PSFtpsActionsConfigPath'. Expected a string or null."
                }
            }
        }
        else {
            Write-Warning "Ignoring invalid SecurityDefault in '$script:PSFtpsActionsConfigPath'. Expected a JSON object."
        }
    }

    $connectionProperty = $config.PSObject.Properties['ConnectionDefault']
    if ($null -ne $connectionProperty -and $null -ne $connectionProperty.Value) {
        $connectionDefault = $connectionProperty.Value

        if ($connectionDefault -is [PSCustomObject]) {
            $integerSettings = @(
                @{ Name = 'TimeoutSeconds'; Minimum = 1; Maximum = 86400 }
                @{ Name = 'RetryCount'; Minimum = 0; Maximum = 100 }
                @{ Name = 'RetryDelaySeconds'; Minimum = 0; Maximum = 86400 }
            )

            foreach ($setting in $integerSettings) {
                $settingProperty = $connectionDefault.PSObject.Properties[$setting.Name]
                if ($null -eq $settingProperty) {
                    continue
                }

                $parsedValue = 0
                $stringValue = [System.Convert]::ToString(
                    $settingProperty.Value,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
                $isInteger = [int]::TryParse(
                    $stringValue,
                    [System.Globalization.NumberStyles]::Integer,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [ref]$parsedValue
                )

                if ($isInteger -and $parsedValue -ge $setting.Minimum -and $parsedValue -le $setting.Maximum) {
                    $loadedConnectionDefault[$setting.Name] = $parsedValue
                }
                else {
                    Write-Warning "Ignoring invalid ConnectionDefault.$($setting.Name) in '$script:PSFtpsActionsConfigPath'. Expected an integer from $($setting.Minimum) through $($setting.Maximum)."
                }
            }
        }
        else {
            Write-Warning "Ignoring invalid ConnectionDefault in '$script:PSFtpsActionsConfigPath'. Expected a JSON object."
        }
    }

    $script:PSFtpsActionsSecurityDefault = $loadedSecurityDefault
    $script:PSFtpsActionsConnectionDefault = $loadedConnectionDefault
}
