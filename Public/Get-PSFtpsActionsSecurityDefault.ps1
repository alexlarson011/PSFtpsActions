<#
.SYNOPSIS
Gets the module default FTPS security settings.

.DESCRIPTION
Returns the current script-scoped FTPS security defaults used by commands when TlsMode or TlsHostCertificateFingerprint are not provided directly.

.EXAMPLE
Get-PSFtpsActionsSecurityDefault

Returns the current module security defaults.
#>
function Get-PSFtpsActionsSecurityDefault {
    [CmdletBinding()]
    param ()

    [PSCustomObject]@{
        TlsMode                       = $script:PSFtpsActionsSecurityDefault.TlsMode
        TlsHostCertificateFingerprint = $script:PSFtpsActionsSecurityDefault.TlsHostCertificateFingerprint
    }
}
