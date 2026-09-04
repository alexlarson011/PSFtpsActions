Set-StrictMode -Version 2.0

$script:ModuleRoot = $PSScriptRoot
$script:DefaultWinScpExePath = Join-Path $script:ModuleRoot 'lib\WinSCP\WinSCP.exe'
$script:DefaultWinScpDllPath = if ($PSVersionTable.PSEdition -eq 'Core') {
    Join-Path $script:ModuleRoot 'lib\WinSCP\netstandard2.0\WinSCPnet.dll'
}
else {
    Join-Path $script:ModuleRoot 'lib\WinSCP\WinSCPnet.dll'
}
$script:CurrentWinScpExePath = $script:DefaultWinScpExePath
$script:PSFtpsActionsSecurityDefault = @{
    TlsMode                       = 'Default'
    TlsHostCertificateFingerprint = $null
}
$script:PSFtpsActionsConnectionDefault = @{
    TimeoutSeconds     = 30
    RetryCount         = 0
    RetryDelaySeconds  = 5
}
$script:PSFtpsActionsCredentialStore = @{}
$script:PSFtpsActionsStorageRoot = Join-Path $env:APPDATA 'PSFtpsActions'
$script:PSFtpsActionsConfigPath = Join-Path $script:PSFtpsActionsStorageRoot 'config.json'
$script:PSFtpsActionsCredentialStorePath = Join-Path $script:PSFtpsActionsStorageRoot 'Credentials'

$privateFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File
$publicFunctions  = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public')  -Filter '*.ps1' -File

foreach ($function in @($privateFunctions + $publicFunctions)) {
    . $function.FullName
}

Load-PSFtpsActionsConfig
Load-PSFtpsCredentialStore

Export-ModuleMember -Function @(
    'Send-FtpsFile',
    'Get-FtpsFile',
    'Get-FtpsChildItem',
    'Remove-FtpsFile',
    'Test-FtpsRemoteFile',
    'Get-TDayFileName',
    'Test-FtpsConnection',
    'Get-FtpsTlsHostCertificateFingerprint',
    'Get-PSFtpsActionsSecurityDefault',
    'Set-PSFtpsActionsSecurityDefault',
    'Get-PSFtpsActionsConnectionDefault',
    'Set-PSFtpsActionsConnectionDefault',
    'Get-PSFtpsCredential',
    'Remove-PSFtpsCredential',
    'Set-PSFtpsCredential',
    'Get-PSFtpsActionsStoragePath',
    'Set-PSFtpsActionsStoragePath'
)
