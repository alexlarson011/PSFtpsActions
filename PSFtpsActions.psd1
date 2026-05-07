@{
    RootModule        = 'PSFtpsActions.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '9b99909c-ef3d-4a59-b3e2-7b1ad47a8f21'
    Author            = 'Alex Larson'
    Description       = 'Reusable FTPS helper functions using WinSCP .NET assembly. Includes support for MVS transmissions.'

    PowerShellVersion = '5.1'

    FunctionsToExport = @(
        'Send-FtpsFile',
        'Get-FtpsFile',
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
        'Set-PSFtpsCredential'
    )

    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = @()
}
