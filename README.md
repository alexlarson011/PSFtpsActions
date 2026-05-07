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
| `Get-FtpsTlsHostCertificateFingerprint` | Scans an FTPS server TLS certificate fingerprint for certificate pinning. |
| `Get-PSFtpsActionsSecurityDefault` | Shows the current module security defaults. |
| `Set-PSFtpsActionsSecurityDefault` | Sets module security defaults for the current PowerShell session. |
| `Get-PSFtpsActionsConnectionDefault` | Shows the current timeout and retry defaults. |
| `Set-PSFtpsActionsConnectionDefault` | Sets timeout and retry defaults for the current PowerShell session. |
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
| `ConvertToUtf8NoBom` | `Send-FtpsFile` only. Uploads a temporary UTF-8 without BOM copy and leaves the source file unchanged. |
| `TrimTrailingWhitespace` | `Send-FtpsFile` only. Removes trailing spaces and tabs from each line in the temporary upload copy. |
| `LineEnding` | `Send-FtpsFile` only. Uses `Preserve` by default. Can be switched to `Windows` CRLF or `Unix` LF. |
| `LogDirectory` | Optional directory for PowerShell transcript logs. |
| `EnableSessionLog` | Enables WinSCP session logging. |
| `TlsMode` | TLS behavior: `Default`, `Tls12Only`, or `Tls12OrHigher`. Defaults to the module security default. |
| `TlsHostCertificateFingerprint` | Optional FTPS server certificate fingerprint. Defaults to the module security default. Values pasted from WinSCP logs or certificate thumbprints are normalized before use. |
| `TimeoutSeconds` | WinSCP timeout in seconds. Defaults to the module connection default, initially `30`. |
| `RetryCount` | Number of additional retry attempts after the first attempt. Defaults to the module connection default, initially `0`. |
| `RetryDelaySeconds` | Delay between retry attempts in seconds. Defaults to the module connection default, initially `5`. |

## Examples

### Test a connection

```powershell
Test-FtpsConnection `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com'
```

### Scan and pin a TLS certificate fingerprint

```powershell
$fingerprint = Get-FtpsTlsHostCertificateFingerprint `
    -HostAddress 'ftps.example.com' |
    Select-Object -ExpandProperty Fingerprint

Test-FtpsConnection `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com' `
    -TlsHostCertificateFingerprint $fingerprint
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

### Upload as normalized text

```powershell
Send-FtpsFile `
    -FilePath 'C:\Temp\outbound.txt' `
    -RemoteFileName 'outbound.txt' `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com' `
    -HostDirectory '/inbound' `
    -ConvertToUtf8NoBom `
    -TrimTrailingWhitespace
```

The source file is not modified. The module creates a temporary UTF-8 without BOM copy, trims trailing spaces and tabs, preserves source line endings, and uploads that copy.

Switch to Windows CRLF line endings when needed:

```powershell
Send-FtpsFile `
    -FilePath 'C:\Temp\outbound.txt' `
    -RemoteFileName 'outbound.txt' `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com' `
    -HostDirectory '/inbound' `
    -ConvertToUtf8NoBom `
    -TrimTrailingWhitespace `
    -LineEnding Windows
```

Switch to Unix LF line endings when needed:

```powershell
Send-FtpsFile `
    -FilePath 'C:\Temp\outbound.txt' `
    -RemoteFileName 'outbound.txt' `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com' `
    -HostDirectory '/inbound' `
    -ConvertToUtf8NoBom `
    -TrimTrailingWhitespace `
    -LineEnding Unix
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

## Connection Defaults

The module has session-scoped timeout and retry defaults:

```powershell
Get-PSFtpsActionsConnectionDefault
```

Fresh module sessions start with:

```text
TimeoutSeconds    = 30
RetryCount        = 0
RetryDelaySeconds = 5
```

Retries default to `0` because repeating uploads and deletes can be surprising. You can opt in for a flaky endpoint:

```powershell
Set-PSFtpsActionsConnectionDefault `
    -TimeoutSeconds 60 `
    -RetryCount 2 `
    -RetryDelaySeconds 10
```

You can also override per command:

```powershell
Send-FtpsFile `
    -FilePath 'C:\Temp\outbound.txt' `
    -RemoteFileName 'outbound.txt' `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com' `
    -HostDirectory '/inbound' `
    -TimeoutSeconds 60 `
    -RetryCount 2 `
    -RetryDelaySeconds 10
```

## TLS Notes

The module's built-in security default is `TlsMode = Default` with no default certificate fingerprint. That means the module does not impose a TLS version constraint or certificate pin unless you configure one. The connection still uses explicit FTPS.

Set your current PowerShell session to require TLS 1.2 by default:

```powershell
Set-PSFtpsActionsSecurityDefault -TlsMode Tls12Only
```

View the current defaults:

```powershell
Get-PSFtpsActionsSecurityDefault
```

Restore the built-in behavior:

```powershell
Set-PSFtpsActionsSecurityDefault -TlsMode Default -ClearTlsHostCertificateFingerprint
```

You can still override the defaults per command:

```powershell
Test-FtpsConnection `
    -Username 'user' `
    -Password 'pass' `
    -HostAddress 'ftps.example.com' `
    -TlsMode Tls12Only
```

When your server requires certificate pinning, use `Get-FtpsTlsHostCertificateFingerprint` to scan the server certificate, verify the returned value through your normal trust process, then pass it to `-TlsHostCertificateFingerprint`.

The fingerprint parameter accepts WinSCP-style values such as:

```text
00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff
```

It also normalizes common pasted forms, including bracketed WinSCP log output, values with a `SHA-256:` or `SHA-1:` prefix, and plain certificate thumbprints.

## Local Integration Testing

The repository includes a local explicit FTPS integration test harness. It starts a temporary Python FTPS server, generates a short-lived self-signed certificate, scans the certificate fingerprint, then exercises connection, upload, remote-file check, download, and delete operations.

Install the development dependencies:

```powershell
python -m pip install --user -r requirements-dev.txt
```

Run the local integration test:

```powershell
.\tests\Invoke-LocalFtpsIntegration.ps1
```

The test creates all files under a temporary directory and removes them when it finishes.
