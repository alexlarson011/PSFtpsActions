function New-FtpsSessionOptions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$HostAddress,

        [Parameter(Mandatory = $false)]
        [int]$Port = 21,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Default', 'Tls12Only', 'Tls12OrHigher')]
        [string]$TlsMode = 'Tls12Only',

        [Parameter(Mandatory = $false)]
        [string]$TlsHostCertificateFingerprint
    )

    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol   = [WinSCP.Protocol]::Ftp
        HostName   = $HostAddress
        PortNumber = $Port
        UserName   = $Username
        Password   = $Password

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

    if (-not [string]::IsNullOrWhiteSpace($TlsHostCertificateFingerprint)) {
        $sessionOptions.TlsHostCertificateFingerprint = $TlsHostCertificateFingerprint
    }

    return $sessionOptions
}