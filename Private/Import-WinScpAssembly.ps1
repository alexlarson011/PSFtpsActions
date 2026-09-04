<#
.SYNOPSIS
Loads the WinSCP .NET assembly used by the module.

.DESCRIPTION
Validates that the requested WinSCPnet.dll path exists and loads it with Add-Type so the public FTPS commands can create WinSCP session objects.
#>
function Import-WinScpAssembly {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$WinScpDllPath = $script:DefaultWinScpDllPath
    )

    if (-not (Test-Path -LiteralPath $WinScpDllPath)) {
        throw "WinSCP .NET assembly not found: $WinScpDllPath"
    }

    $resolvedDllPath = (Get-Item -LiteralPath $WinScpDllPath -ErrorAction Stop).FullName
    $dllDirectory = Split-Path -Parent $resolvedDllPath
    $executableCandidates = @(
        (Join-Path $dllDirectory 'WinSCP.exe'),
        (Join-Path (Split-Path -Parent $dllDirectory) 'WinSCP.exe')
    )
    $script:CurrentWinScpExePath = $null
    $matchingExecutable = $executableCandidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if ($matchingExecutable) {
        $script:CurrentWinScpExePath = (Get-Item -LiteralPath $matchingExecutable).FullName
    }

    Add-Type -Path $resolvedDllPath
}
