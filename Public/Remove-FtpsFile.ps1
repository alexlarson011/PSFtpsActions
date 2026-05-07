function Remove-FtpsFile {
    [CmdletBinding()]
    param (
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

    $operationName = 'Remove-FtpsFile'
    $transcriptStarted = $false
    $session = $null

    try {
        if (-not [string]::IsNullOrWhiteSpace($LogDirectory)) {
            Start-FtpsTranscript -LogDirectory $LogDirectory -OperationName $operationName | Out-Null
            $transcriptStarted = $true
        }

        Import-WinScpAssembly -WinScpDllPath $WinScpDllPath

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

        Write-Host "Deleting remote file:"
        Write-Host $remotePath

        if ($MvsMode) {
            Write-Host "Using MVS delete command:"
            Write-Host "DELE $RemoteFileName"

            $deleteResult = $session.ExecuteCommand("DELE $RemoteFileName")

            if (-not [string]::IsNullOrWhiteSpace($deleteResult.Output)) {
                Write-Host "Delete output:"
                Write-Host $deleteResult.Output
            }

            if ($deleteResult.ExitCode -ne 0) {
                throw "MVS remote delete failed. ExitCode=$($deleteResult.ExitCode). Output: $($deleteResult.Output)"
            }
        }
        else {
            $removeResult = $session.RemoveFiles($remotePath)
            $removeResult.Check()
        }

        Write-Host "Remote file deleted successfully."
    }
    catch {
        throw "FTPS remote delete failed. $($_.Exception.Message)"
    }
    finally {
        if ($session) {
            $session.Dispose()
        }

        if ($transcriptStarted) {
            Stop-Transcript | Out-Null
        }
    }
}