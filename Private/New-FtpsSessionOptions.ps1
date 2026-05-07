<#
.SYNOPSIS
Builds WinSCP session options for explicit FTPS.

.DESCRIPTION
Creates a WinSCP.SessionOptions object with FTP protocol, explicit FTPS, passive mode, credentials, port, and optional TLS version and certificate fingerprint settings.
#>
function New-FtpsSessionOptions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$HostAddress,

        [Parameter(Mandatory = $false)]
        [int]$Port = 21,

        [Parameter(Mandatory = $true)]
        [pscredential]$Credential,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Default', 'Tls12Only', 'Tls12OrHigher')]
        [string]$TlsMode = 'Default',

        [Parameter(Mandatory = $false)]
        [string]$TlsHostCertificateFingerprint,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds = 30
    )

    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol   = [WinSCP.Protocol]::Ftp
        HostName   = $HostAddress
        PortNumber = $Port
        UserName   = $Credential.UserName
        Password   = $Credential.GetNetworkCredential().Password

        # Explicit FTPS
        FtpSecure  = [WinSCP.FtpSecure]::Explicit

        # Passive FTP/FTPS; this is the default, but I like being explicit
        FtpMode    = [WinSCP.FtpMode]::Passive
    }

    switch ($TlsMode) {
        'Tls12Only' {
            $sessionOptions.AddRawSettings('MinTlsVersion', '12')
            $sessionOptions.AddRawSettings('MaxTlsVersion', '12')
        }

        'Tls12OrHigher' {
            $sessionOptions.AddRawSettings('MinTlsVersion', '12')
        }

        'Default' {
            # Let WinSCP choose.
        }
    }

    $normalizedFingerprint = Normalize-TlsHostCertificateFingerprint -Fingerprint $TlsHostCertificateFingerprint

    if (-not [string]::IsNullOrWhiteSpace($normalizedFingerprint)) {
        $sessionOptions.TlsHostCertificateFingerprint = $normalizedFingerprint
    }

    $sessionOptions.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)

    return $sessionOptions
}
