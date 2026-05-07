<#
.SYNOPSIS
Resolves effective FTPS security settings.

.DESCRIPTION
Combines command-level TLS settings with the module security default hashtable. Explicit command parameters win over configured defaults.
#>
function Resolve-FtpsSecuritySettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$BoundParameters,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TlsMode,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$TlsHostCertificateFingerprint
    )

    $effectiveTlsMode = $script:PSFtpsActionsSecurityDefault.TlsMode
    $effectiveFingerprint = $script:PSFtpsActionsSecurityDefault.TlsHostCertificateFingerprint

    if ($BoundParameters.ContainsKey('TlsMode')) {
        $effectiveTlsMode = $TlsMode
    }

    if ($BoundParameters.ContainsKey('TlsHostCertificateFingerprint')) {
        $effectiveFingerprint = $TlsHostCertificateFingerprint
    }

    if ([string]::IsNullOrWhiteSpace($effectiveTlsMode)) {
        $effectiveTlsMode = 'Default'
    }

    [PSCustomObject]@{
        TlsMode                       = $effectiveTlsMode
        TlsHostCertificateFingerprint = $effectiveFingerprint
    }
}
