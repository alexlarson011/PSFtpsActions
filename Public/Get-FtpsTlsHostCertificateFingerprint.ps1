<#
.SYNOPSIS
Scans an FTPS server TLS certificate fingerprint.

.DESCRIPTION
Uses WinSCP's Session.ScanFingerprint method to read the TLS certificate fingerprint from an explicit FTPS server without opening an authenticated file-transfer session. The returned fingerprint can be passed to the TlsHostCertificateFingerprint parameter on the module's FTPS commands.

.PARAMETER HostAddress
FTPS server host name or IP address.

.PARAMETER Port
FTPS server port. Defaults to 21.

.PARAMETER Algorithm
Fingerprint algorithm to request from WinSCP. SHA-256 is recommended and is the default.

.PARAMETER WinScpDllPath
Path to WinSCPnet.dll. Defaults to the bundled assembly under the module's lib folder.

.PARAMETER LogDirectory
Optional directory for a WinSCP session log.

.PARAMETER EnableSessionLog
Enables a WinSCP session log. Uses LogDirectory when provided, otherwise the temp directory.

.PARAMETER TlsMode
Controls WinSCP TLS raw settings. Defaults to the module security default.

.EXAMPLE
Get-FtpsTlsHostCertificateFingerprint -HostAddress 'ftps.example.com'

Scans ftps.example.com on port 21 and returns its SHA-256 TLS certificate fingerprint.

.EXAMPLE
$fingerprint = Get-FtpsTlsHostCertificateFingerprint -HostAddress 'ftps.example.com' | Select-Object -ExpandProperty Fingerprint
Test-FtpsConnection -Username 'user' -Password 'pass' -HostAddress 'ftps.example.com' -TlsHostCertificateFingerprint $fingerprint

Scans a fingerprint and uses it for a pinned FTPS connection test.
#>
function Get-FtpsTlsHostCertificateFingerprint {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$HostAddress,

        [Parameter(Mandatory = $false)]
        [int]$Port = 21,

        [Parameter(Mandatory = $false)]
        [ValidateSet('SHA-256', 'SHA-1')]
        [string]$Algorithm = 'SHA-256',

        [Parameter(Mandatory = $false)]
        [string]$WinScpDllPath = $script:DefaultWinScpDllPath,

        [Parameter(Mandatory = $false)]
        [string]$LogDirectory,

        [Parameter(Mandatory = $false)]
        [switch]$EnableSessionLog,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Default', 'Tls12Only', 'Tls12OrHigher')]
        [string]$TlsMode
    )

    $operationName = 'Get-FtpsTlsHostCertificateFingerprint'
    $session = $null

    try {
        Import-WinScpAssembly -WinScpDllPath $WinScpDllPath

        $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
            Protocol   = [WinSCP.Protocol]::Ftp
            HostName   = $HostAddress
            PortNumber = $Port
            FtpSecure  = [WinSCP.FtpSecure]::Explicit
            FtpMode    = [WinSCP.FtpMode]::Passive
        }

        $securitySettings = Resolve-FtpsSecuritySettings `
            -BoundParameters $PSBoundParameters `
            -TlsMode $TlsMode

        switch ($securitySettings.TlsMode) {
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

        $session = New-FtpsSession `
            -LogDirectory $LogDirectory `
            -EnableSessionLog:$EnableSessionLog `
            -OperationName $operationName

        Write-Host "Scanning FTPS TLS certificate fingerprint..."
        Write-Host "Host     : $HostAddress"
        Write-Host "Port     : $Port"
        Write-Host "Algorithm: $Algorithm"

        $fingerprint = $session.ScanFingerprint($sessionOptions, $Algorithm)
        $fingerprint = Normalize-TlsHostCertificateFingerprint -Fingerprint $fingerprint

        [PSCustomObject]@{
            HostAddress = $HostAddress
            Port        = $Port
            Algorithm   = $Algorithm
            Fingerprint = $fingerprint
        }
    }
    catch {
        throw "FTPS TLS certificate fingerprint scan failed. $($_.Exception.Message)"
    }
    finally {
        if ($session) {
            $session.Dispose()
        }
    }
}
