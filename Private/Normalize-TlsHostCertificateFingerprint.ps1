<#
.SYNOPSIS
Normalizes a TLS host certificate fingerprint for WinSCP.

.DESCRIPTION
Accepts fingerprints pasted from WinSCP logs, PowerShell certificate thumbprints, or colon-delimited values. Returns a WinSCP-friendly fingerprint string when the value can be normalized, otherwise returns the trimmed input.
#>
function Normalize-TlsHostCertificateFingerprint {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$Fingerprint
    )

    if ([string]::IsNullOrWhiteSpace($Fingerprint)) {
        return $null
    }

    $normalized = $Fingerprint.Trim().Trim('[', ']')

    if ($normalized.Contains(';')) {
        return $normalized
    }

    $algorithm = $null
    $body = $normalized

    if ($normalized -match '^(SHA-256|SHA-1)\s*:\s*(.+)$') {
        $algorithm = $matches[1].ToUpperInvariant()
        $body = $matches[2]
    }

    $hexOnly = $body -replace '[^0-9A-Fa-f]', ''

    if ([string]::IsNullOrWhiteSpace($algorithm)) {
        if ($hexOnly.Length -eq 64) {
            $algorithm = 'SHA-256'
        }
        elseif ($hexOnly.Length -eq 40) {
            $algorithm = 'SHA-1'
        }
    }

    if (
        ($algorithm -eq 'SHA-256' -and $hexOnly.Length -eq 64) -or
        ($algorithm -eq 'SHA-1' -and $hexOnly.Length -eq 40)
    ) {
        $pairs = for ($index = 0; $index -lt $hexOnly.Length; $index += 2) {
            $hexOnly.Substring($index, 2).ToLowerInvariant()
        }

        return "${algorithm}: $($pairs -join ':')"
    }

    if (-not [string]::IsNullOrWhiteSpace($algorithm)) {
        return "${algorithm}: $($body.Trim())"
    }

    return $normalized
}
