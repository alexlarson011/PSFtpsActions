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

    Add-Type -Path $WinScpDllPath
}
