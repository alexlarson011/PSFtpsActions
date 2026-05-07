function Test-FtpsConnection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [string]$Password,

        [Parameter(Mandatory = $true)]
        [string]$HostAddress,

        [Parameter(Mandatory = $false)]
        [int]$Port = 21,

        [Parameter(Mandatory = $false)]
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

    $operationName = 'Test-FtpsConnection'
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

        Write-Host "Testing explicit FTPS connection..."
        Write-Host "Host: $HostAddress"
        Write-Host "Port: $Port"
        Write-Host "User: $Username"

        $session.Open($sessionOptions)

        Write-Host "Connection opened successfully."

        Invoke-FtpsSiteCommand `
            -Session $session `
            -SiteCommand $SiteCommand

        if (-not [string]::IsNullOrWhiteSpace($HostDirectory)) {
            if ($MvsMode) {
                $mvsDatasetPrefix = Normalize-MvsDatasetPrefix -DatasetPrefix $HostDirectory

                Write-Host "Testing MVS dataset prefix:"
                Write-Host $mvsDatasetPrefix

                $cwdResult = $session.ExecuteCommand("CWD $mvsDatasetPrefix")

                if (-not [string]::IsNullOrWhiteSpace($cwdResult.Output)) {
                    Write-Host "CWD output:"
                    Write-Host $cwdResult.Output
                }

                if ($cwdResult.ExitCode -ne 0) {
                    throw "MVS CWD failed. ExitCode=$($cwdResult.ExitCode). Output: $($cwdResult.Output)"
                }
            }
            else {
                $normalizedDirectory = Normalize-RemoteDirectory -Directory $HostDirectory

                Write-Host "Testing remote directory:"
                Write-Host $normalizedDirectory

                $session.ListDirectory($normalizedDirectory) | Out-Null
            }
        }

        Write-Host "FTPS connection test succeeded."

        [PSCustomObject]@{
            Success       = $true
            HostAddress   = $HostAddress
            Port          = $Port
            Username      = $Username
            HostDirectory = $HostDirectory
            MvsMode       = [bool]$MvsMode
            Message       = 'Connection test succeeded.'
        }
    }
    catch {
        [PSCustomObject]@{
            Success       = $false
            HostAddress   = $HostAddress
            Port          = $Port
            Username      = $Username
            HostDirectory = $HostDirectory
            MvsMode       = [bool]$MvsMode
            Message       = $_.Exception.Message
        }
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