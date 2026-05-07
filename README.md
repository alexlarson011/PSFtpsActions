# PSFtpsActions

PowerShell helper module for explicit FTPS transfers using the WinSCP .NET assembly. The module includes common upload, download, delete, connection-test, and remote-file-check commands, plus support for MVS dataset-prefix workflows.

## Requirements

- Windows PowerShell 5.1 or later
- The bundled WinSCP files under `lib\WinSCP`
- Access to an FTPS endpoint that supports explicit FTPS

## Installation

Place the module folder under a path in `$env:PSModulePath`. For this workstation, the module is located at:

```powershell
C:\PSModules\PSFtpsActions
```

Import the module by name:

```powershell
Import-Module PSFtpsActions
```

Confirm the exported commands:

```powershell
Get-Command -Module PSFtpsActions
```

## Commands

| Command | Description |
| --- | --- |
| `Send-FtpsFile` | Uploads a local file using explicit FTPS. |
| `Get-FtpsFile` | Downloads a remote file using explicit FTPS. |
| `Remove-FtpsFile` | Deletes a remote file. |
| `Test-FtpsRemoteFile` | Checks whether a remote file exists and returns metadata when available. |
| `Test-FtpsConnection` | Tests the FTPS connection and optionally validates a remote directory or MVS dataset prefix. |
| `Get-TDayFileName` | Builds a prefix plus padded day-of-year file name such as `T127`. |

Use `Get-Help` for detailed command help:

```powershell
Get-Help Send-FtpsFile -Detailed
Get-Help Get-FtpsFile -Examples
```

## Common Parameters

Most FTPS commands share these parameters:

| Parameter | Description |
| --- | --- |
| `Username` | FTPS username. |
| `Password` | FTPS password. |
| `HostAddress` | FTPS server host name or IP address. |
| `Port` | FTPS port. Defaults to `21`. |
| `HostDirectory` | Remote directory, or an MVS dataset prefix when `-MvsMode` is used. |
| `SiteCommand` | Optional command sent after connection and before the file operation. |
| `MvsMode` | Uses MVS dataset-prefix navigation. |
| `LogDirectory` | Optional directory for PowerShell transcript logs. |
| `EnableSessionLog` | Enables WinSCP session logging. |
| `TlsMode` | TLS behavior: `Default`, `Tls12Only`, or `Tls12OrHigher`. Defaults to `Tls12Only`. |
| `TlsHostCertificateFingerprint` | Optional FTPS server certificate fingerprint. |

## Examples

### Test a connection

```powershell
Test-FtpsConnection `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com'
```

### Upload a file

```powershell
Send-FtpsFile `
    -FilePath 'C:\Temp\outbound.txt' `
    -RemoteFileName 'outbound.txt' `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com' `
    -HostDirectory '/inbound'
```

### Download a file

```powershell
Get-FtpsFile `
    -RemoteFileName 'inbound.txt' `
    -LocalDirectory 'C:\Temp' `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com' `
    -HostDirectory '/outbound'
```

### Download and delete the remote file

```powershell
Get-FtpsFile `
    -RemoteFileName 'inbound.txt' `
    -LocalDirectory 'C:\Temp' `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com' `
    -HostDirectory '/outbound' `
    -DeleteRemoteAfterDownload
```

### Use MVS mode

```powershell
Send-FtpsFile `
    -FilePath 'C:\Temp\report.txt' `
    -RemoteFileName 'REPORT.TXT' `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'mvs.example.com' `
    -HostDirectory 'HLQ.APP.DATA' `
    -MvsMode
```

In MVS mode, `HostDirectory` is normalized as a dataset prefix and the module changes to that prefix before sending the file operation.

### Build a T-day file name

```powershell
Get-TDayFileName -Date '2026-05-07'
```

Returns:

```text
T127
```

## Logging

Passing `-LogDirectory` starts a PowerShell transcript for the operation. Passing `-EnableSessionLog` also enables a WinSCP session log. When both are used, both logs are written under the provided log directory.

```powershell
Send-FtpsFile `
    -FilePath 'C:\Temp\outbound.txt' `
    -RemoteFileName 'outbound.txt' `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com' `
    -HostDirectory '/inbound' `
    -LogDirectory 'C:\Temp\FtpsLogs' `
    -EnableSessionLog
```

## TLS Notes

The module defaults to `Tls12Only`, which sets both minimum and maximum TLS version to TLS 1.2 through WinSCP raw settings. Use `Tls12OrHigher` when the server supports newer TLS versions, or `Default` to let WinSCP choose.

When your server requires certificate pinning, pass `-TlsHostCertificateFingerprint`.
