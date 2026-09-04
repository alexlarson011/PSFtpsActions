<#
.SYNOPSIS
Sets module default FTPS security settings.

.DESCRIPTION
Updates the FTPS security defaults used by module commands when TlsMode or TlsHostCertificateFingerprint are omitted. Defaults are saved to the configured local config path.

.PARAMETER TlsMode
Default TLS behavior. Default lets WinSCP choose. Tls12Only constrains connections to TLS 1.2. Tls12OrHigher requires TLS 1.2 or newer.

.PARAMETER TlsHostCertificateFingerprint
Default TLS host certificate fingerprint for certificate pinning. Empty string clears the default.

.PARAMETER ClearTlsHostCertificateFingerprint
Clears the default TLS host certificate fingerprint.

.EXAMPLE
Set-PSFtpsActionsSecurityDefault -TlsMode Tls12Only

Uses TLS 1.2 only as the module default for the current PowerShell session.

.EXAMPLE
Set-PSFtpsActionsSecurityDefault -TlsMode Default -ClearTlsHostCertificateFingerprint

Restores default TLS behavior and clears certificate pinning.
#>
function Set-PSFtpsActionsSecurityDefault {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet('Default', 'Tls12Only', 'Tls12OrHigher')]
        [string]$TlsMode,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$TlsHostCertificateFingerprint,

        [Parameter(Mandatory = $false)]
        [switch]$ClearTlsHostCertificateFingerprint
    )

    $updatedSecurityDefault = @{
        TlsMode                        = $script:PSFtpsActionsSecurityDefault.TlsMode
        TlsHostCertificateFingerprint = $script:PSFtpsActionsSecurityDefault.TlsHostCertificateFingerprint
    }

    if ($PSBoundParameters.ContainsKey('TlsMode')) {
        $updatedSecurityDefault.TlsMode = $TlsMode
    }

    if ($ClearTlsHostCertificateFingerprint) {
        $updatedSecurityDefault.TlsHostCertificateFingerprint = $null
    }
    elseif ($PSBoundParameters.ContainsKey('TlsHostCertificateFingerprint')) {
        $updatedSecurityDefault.TlsHostCertificateFingerprint = Normalize-TlsHostCertificateFingerprint -Fingerprint $TlsHostCertificateFingerprint
    }

    Save-PSFtpsActionsConfig `
        -SecurityDefault $updatedSecurityDefault `
        -ConnectionDefault $script:PSFtpsActionsConnectionDefault

    $script:PSFtpsActionsSecurityDefault = $updatedSecurityDefault

    Get-PSFtpsActionsSecurityDefault
}
