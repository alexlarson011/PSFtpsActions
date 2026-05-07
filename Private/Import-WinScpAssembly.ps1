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