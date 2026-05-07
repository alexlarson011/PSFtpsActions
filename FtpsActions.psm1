Set-StrictMode -Version 2.0

$script:ModuleRoot = $PSScriptRoot
$script:DefaultWinScpDllPath = Join-Path $script:ModuleRoot 'lib\WinSCP\WinSCPnet.dll'

$privateFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File
$publicFunctions  = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -File

foreach ($function in @($privateFunctions + $publicFunctions)) {
    . $function.FullName
}

Export-ModuleMember -Function @(
    'Send-FtpsFile',
    'Get-FtpsFile',
    'Remove-FtpsFile',
    'Test-FtpsRemoteFile',
    'Get-TDayFileName',
    'Test-FtpsConnection'
)