<#
.SYNOPSIS
Uploads a local file to an explicit FTPS endpoint.

.DESCRIPTION
Connects to an FTPS server using the bundled WinSCP .NET assembly, optionally sends a SITE command, resolves the target remote location, and uploads a file in ASCII transfer mode. Supports standard FTP paths and MVS dataset-prefix navigation. Can optionally upload a temporary normalized text copy of the source file.

.PARAMETER FilePath
Path to the local file to upload.

.PARAMETER RemoteFileName
Name to use for the uploaded remote file or MVS member/data set name.

.PARAMETER Username
FTPS username.

.PARAMETER Password
FTPS password.

.PARAMETER HostAddress
FTPS server host name or IP address.

.PARAMETER Port
FTPS server port. Defaults to 21.

.PARAMETER HostDirectory
Remote directory for standard FTPS paths, or MVS dataset prefix when MvsMode is used.

.PARAMETER SiteCommand
Optional SITE command to send after connecting and before file operations.

.PARAMETER MvsMode
Uses MVS dataset-prefix navigation instead of standard FTP path concatenation.

.PARAMETER ConvertToUtf8NoBom
Uploads a temporary UTF-8 without BOM copy of the source file. The original file is not modified.

.PARAMETER TrimTrailingWhitespace
Uploads a temporary copy with trailing spaces and tabs removed from each line. The original file is not modified.

.PARAMETER LineEnding
Line ending handling for the temporary upload copy. Preserve leaves line endings as read from the source file and is the default. Windows uses CRLF. Unix uses LF.

.PARAMETER WinScpDllPath
Path to WinSCPnet.dll. Defaults to the bundled assembly under the module's lib folder.

.PARAMETER LogDirectory
Optional directory for PowerShell transcript logs.

.PARAMETER EnableSessionLog
Enables a WinSCP session log. Uses LogDirectory when provided, otherwise the temp directory.

.PARAMETER TlsMode
Controls WinSCP TLS raw settings. Defaults to Tls12Only.

.PARAMETER TlsHostCertificateFingerprint
Optional TLS host certificate fingerprint to validate the FTPS server certificate. Values pasted from WinSCP logs or certificate thumbprints are normalized before being passed to WinSCP.

.EXAMPLE
Send-FtpsFile -FilePath 'C:\Temp\outbound.txt' -RemoteFileName 'outbound.txt' -Username 'user' -Password 'pass' -HostAddress 'ftps.example.com' -HostDirectory '/inbound'

Uploads C:\Temp\outbound.txt to /inbound/outbound.txt.

.EXAMPLE
Send-FtpsFile -FilePath 'C:\Temp\report.txt' -RemoteFileName 'REPORT.TXT' -Username 'user' -Password 'pass' -HostAddress 'mvs.example.com' -HostDirectory 'HLQ.APP.DATA' -MvsMode

Changes to the MVS dataset prefix and uploads report.txt as REPORT.TXT.

.EXAMPLE
Send-FtpsFile -FilePath 'C:\Temp\outbound.txt' -RemoteFileName 'outbound.txt' -Username 'user' -Password 'pass' -HostAddress 'ftps.example.com' -HostDirectory '/inbound' -ConvertToUtf8NoBom

Uploads a temporary UTF-8 without BOM copy of C:\Temp\outbound.txt while preserving source line endings.

.EXAMPLE
Send-FtpsFile -FilePath 'C:\Temp\outbound.txt' -RemoteFileName 'outbound.txt' -Username 'user' -Password 'pass' -HostAddress 'ftps.example.com' -HostDirectory '/inbound' -ConvertToUtf8NoBom -TrimTrailingWhitespace -LineEnding Unix

Uploads a temporary UTF-8 without BOM copy with trailing spaces/tabs removed and LF line endings.
#>
function Send-FtpsFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$RemoteFileName,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [string]$HostAddress,

        [Parameter(Mandatory = $false)]
        [int]$Port = 21,

        [Parameter(Mandatory = $true)]
        [string]$HostDirectory,

        [Parameter(Mandatory = $false)]
        [string]$SiteCommand,

        [Parameter(Mandatory = $false)]
        [switch]$MvsMode,

        [Parameter(Mandatory = $false)]
        [switch]$ConvertToUtf8NoBom,

        [Parameter(Mandatory = $false)]
        [switch]$TrimTrailingWhitespace,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Preserve', 'Windows', 'Unix')]
        [string]$LineEnding = 'Preserve',

        [Parameter(Mandatory = $false)]
        [string]$WinScpDllPath = $script:DefaultWinScpDllPath,

        [Parameter(Mandatory = $false)]
        [string]$LogDirectory,

        [Parameter(Mandatory = $false)]
        [switch]$EnableSessionLog,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Default', 'Tls12Only', 'Tls12OrHigher')]
        [string]$TlsMode = 'Tls12Only',

        [Parameter(Mandatory = $false)]
        [string]$TlsHostCertificateFingerprint
    )

    $operationName = 'Send-FtpsFile'
    $transcriptStarted = $false
    $session = $null
    $temporaryUploadPath = $null

    try {
        if (-not [string]::IsNullOrWhiteSpace($LogDirectory)) {
            Start-FtpsTranscript -LogDirectory $LogDirectory -OperationName $operationName | Out-Null
            $transcriptStarted = $true
        }

        if (-not (Test-Path -LiteralPath $FilePath)) {
            throw "File not found: $FilePath"
        }

        Import-WinScpAssembly -WinScpDllPath $WinScpDllPath

        $fileInfo = Get-Item -LiteralPath $FilePath

        if ($ConvertToUtf8NoBom -or $TrimTrailingWhitespace -or $PSBoundParameters.ContainsKey('LineEnding')) {
            $temporaryUploadPath = Join-Path ([System.IO.Path]::GetTempPath()) ("PSFtpsActions_Normalized_{0}_{1}" -f ([guid]::NewGuid().ToString('N')), $fileInfo.Name)
            $fileInfo = ConvertTo-Utf8NoBomFile `
                -SourcePath $fileInfo.FullName `
                -DestinationPath $temporaryUploadPath `
                -TrimTrailingWhitespace:$TrimTrailingWhitespace `
                -LineEnding $LineEnding
        }

        $sessionOptions = New-FtpsSessionOptions `
            -HostAddress $HostAddress `
            -Port $Port `
            -Username $Username `
            -Password $Password `
            -TlsMode $TlsMode `
            -TlsHostCertificateFingerprint $TlsHostCertificateFingerprint

        $session = New-FtpsSession `
            -LogDirectory $LogDirectory `
            -EnableSessionLog:$EnableSessionLog `
            -OperationName $operationName

        Write-Host "Connecting to $HostAddress on port $Port using explicit FTPS..."
        $session.Open($sessionOptions)

        Invoke-FtpsSiteCommand `
            -Session $session `
            -SiteCommand $SiteCommand

        $remotePath = Set-FtpsRemoteLocation `
            -Session $session `
            -HostDirectory $HostDirectory `
            -RemoteFileName $RemoteFileName `
            -MvsMode:$MvsMode

        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Ascii

        Write-Host "Uploading file..."
        Write-Host "Local file : $($fileInfo.FullName)"
        Write-Host "UTF-8 no BOM conversion: $ConvertToUtf8NoBom"
        Write-Host "Trim trailing whitespace: $TrimTrailingWhitespace"
        Write-Host "Line ending: $LineEnding"
        Write-Host "Remote file: $remotePath"
        Write-Host "Mode       : ASCII"
        Write-Host "MVS mode   : $MvsMode"

        $transferResult = $session.PutFiles(
            $fileInfo.FullName,
            $remotePath,
            $false,
            $transferOptions
        )

        $transferResult.Check()

        foreach ($transfer in $transferResult.Transfers) {
            Write-Host "Uploaded: $($transfer.FileName)"
        }

        Write-Host "Upload complete."
    }
    catch {
        throw "FTPS upload failed. $($_.Exception.Message)"
    }
    finally {
        if ($session) {
            $session.Dispose()
        }

        if ($transcriptStarted) {
            Stop-Transcript | Out-Null
        }

        if (-not [string]::IsNullOrWhiteSpace($temporaryUploadPath) -and (Test-Path -LiteralPath $temporaryUploadPath)) {
            Remove-Item -LiteralPath $temporaryUploadPath -Force
        }
    }
}
