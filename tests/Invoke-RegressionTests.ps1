[CmdletBinding()]
param ()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$moduleManifest = Join-Path $repoRoot 'PSFtpsActions.psd1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("PSFtpsActions_Regression_" + [guid]::NewGuid().ToString('N'))
$originalAppData = $env:APPDATA
$script:ModuleUnderTest = $null
$script:PassedCount = 0
$script:Failures = @()

function Assert-True {
    param (
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param (
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$Expected,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$Actual,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($Expected -ne $Actual) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

function Assert-SetEqual {
    param (
        [Parameter(Mandatory = $true)]
        [object[]]$Expected,

        [Parameter(Mandatory = $true)]
        [object[]]$Actual,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $differences = @(Compare-Object -ReferenceObject @($Expected | Sort-Object) -DifferenceObject @($Actual | Sort-Object))
    if ($differences.Count -gt 0) {
        throw "$Message Expected '$($Expected -join ', ')', got '$($Actual -join ', ')'."
    }
}

function Invoke-RegressionTest {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    try {
        & $ScriptBlock
        $script:PassedCount++
        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    catch {
        $script:Failures += [PSCustomObject]@{
            Name    = $Name
            Message = $_.Exception.Message
        }
        Write-Host "[FAIL] $Name" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Import-ModuleUnderTest {
    Remove-Module -Name PSFtpsActions -Force -ErrorAction SilentlyContinue
    Import-Module -Name $moduleManifest -Force -ErrorAction Stop
    $script:ModuleUnderTest = Get-Module -Name PSFtpsActions

    if (-not $script:ModuleUnderTest) {
        throw 'PSFtpsActions did not remain loaded after Import-Module completed.'
    }
}

function Get-FunctionParameterDefaultValue {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.FunctionInfo]$Command,

        [Parameter(Mandatory = $true)]
        [string]$ParameterName
    )

    $parameterAst = $Command.ScriptBlock.Ast.FindAll(
        {
            param ($ast)

            $ast -is [System.Management.Automation.Language.ParameterAst] -and
                $ast.Name.VariablePath.UserPath -eq $ParameterName
        },
        $true
    ) | Select-Object -First 1

    if (-not $parameterAst) {
        throw "Parameter '$ParameterName' was not found on '$($Command.Name)'."
    }

    if (-not $parameterAst.DefaultValue) {
        return $null
    }

    $parameterAst.DefaultValue.SafeGetValue()
}

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $env:APPDATA = Join-Path $testRoot 'AppData'
    New-Item -ItemType Directory -Path $env:APPDATA -Force | Out-Null
    Import-ModuleUnderTest

    Invoke-RegressionTest -Name 'The bundled WinSCP assembly matches the active PowerShell edition' -ScriptBlock {
        $defaultDllPath = & $script:ModuleUnderTest {
            $script:DefaultWinScpDllPath
        }
        $defaultExePath = & $script:ModuleUnderTest {
            $script:DefaultWinScpExePath
        }

        Assert-True -Condition (Test-Path -LiteralPath $defaultDllPath -PathType Leaf) -Message "The default WinSCP assembly does not exist: $defaultDllPath"
        Assert-True -Condition (Test-Path -LiteralPath $defaultExePath -PathType Leaf) -Message "The default WinSCP executable does not exist: $defaultExePath"

        if ($PSVersionTable.PSEdition -eq 'Core') {
            Assert-True -Condition ($defaultDllPath -like '*\netstandard2.0\WinSCPnet.dll') -Message 'PowerShell Core did not select the netstandard2.0 WinSCP assembly.'
        }
        else {
            Assert-True -Condition ($defaultDllPath -notlike '*\netstandard2.0\WinSCPnet.dll') -Message 'Windows PowerShell unexpectedly selected the netstandard2.0 WinSCP assembly.'
        }
    }

    Invoke-RegressionTest -Name 'Invoke-FtpsRetry returns a successful first result without retrying' -ScriptBlock {
        $state = [PSCustomObject]@{ Attempts = 0 }

        $result = & $script:ModuleUnderTest {
            param ($testState)

            Invoke-FtpsRetry `
                -RetryCount 3 `
                -RetryDelaySeconds 0 `
                -OperationName 'Regression success' `
                -ScriptBlock {
                    $testState.Attempts++
                    'completed'
                }
        } $state

        Assert-Equal -Expected 'completed' -Actual $result -Message 'The successful result was not returned.'
        Assert-Equal -Expected 1 -Actual $state.Attempts -Message 'A successful operation ran an unexpected number of times.'
    }

    Invoke-RegressionTest -Name 'Invoke-FtpsRetry retries thrown failures and returns the later result' -ScriptBlock {
        $state = [PSCustomObject]@{ Attempts = 0 }

        $result = & $script:ModuleUnderTest {
            param ($testState)

            Invoke-FtpsRetry `
                -RetryCount 2 `
                -RetryDelaySeconds 0 `
                -OperationName 'Regression transient failure' `
                -ScriptBlock {
                    $testState.Attempts++
                    if ($testState.Attempts -lt 3) {
                        throw "transient failure $($testState.Attempts)"
                    }

                    'recovered'
                }
        } $state

        Assert-Equal -Expected 'recovered' -Actual $result -Message 'The recovered result was not returned.'
        Assert-Equal -Expected 3 -Actual $state.Attempts -Message 'RetryCount did not represent additional attempts.'
    }

    Invoke-RegressionTest -Name 'Invoke-FtpsRetry rethrows the final failure after exhausting retries' -ScriptBlock {
        $state = [PSCustomObject]@{ Attempts = 0 }
        $caught = $null

        try {
            & $script:ModuleUnderTest {
                param ($testState)

                Invoke-FtpsRetry `
                    -RetryCount 2 `
                    -RetryDelaySeconds 0 `
                    -OperationName 'Regression terminal failure' `
                    -ScriptBlock {
                        $testState.Attempts++
                        throw "terminal failure $($testState.Attempts)"
                    }
            } $state
        }
        catch {
            $caught = $_
        }

        Assert-True -Condition ($null -ne $caught) -Message 'The final failure was swallowed.'
        Assert-Equal -Expected 3 -Actual $state.Attempts -Message 'The failing operation ran an unexpected number of times.'
        Assert-True -Condition ($caught.Exception.Message -like '*terminal failure 3*') -Message 'The last exception was not rethrown.'
    }

    Invoke-RegressionTest -Name 'Normalize-RemoteDirectory produces rooted trailing-slash paths' -ScriptBlock {
        $cases = @(
            @{ Input = '/'; Expected = '/' },
            @{ Input = ' inbound '; Expected = '/inbound/' },
            @{ Input = '/outbound'; Expected = '/outbound/' },
            @{ Input = 'nested/path/'; Expected = '/nested/path/' }
        )

        foreach ($case in $cases) {
            $actual = & $script:ModuleUnderTest {
                param ($value)
                Normalize-RemoteDirectory -Directory $value
            } $case.Input

            Assert-Equal -Expected $case.Expected -Actual $actual -Message "Remote directory normalization failed for '$($case.Input)'."
        }
    }

    Invoke-RegressionTest -Name 'Normalize-MvsDatasetPrefix produces one quoted trailing-period prefix' -ScriptBlock {
        $cases = @(
            @{ Input = 'HLQ.APP.DATA'; Expected = "'HLQ.APP.DATA.'" },
            @{ Input = "'HLQ.APP.DATA.'"; Expected = "'HLQ.APP.DATA.'" },
            @{ Input = "  'HLQ.APP.DATA'  "; Expected = "'HLQ.APP.DATA.'" }
        )

        foreach ($case in $cases) {
            $actual = & $script:ModuleUnderTest {
                param ($value)
                Normalize-MvsDatasetPrefix -DatasetPrefix $value
            } $case.Input

            Assert-Equal -Expected $case.Expected -Actual $actual -Message "MVS dataset-prefix normalization failed for '$($case.Input)'."
        }
    }

    Invoke-RegressionTest -Name 'Remote command inputs reject protocol line breaks' -ScriptBlock {
        foreach ($case in @(
            @{ Function = 'Normalize-RemoteDirectory'; Parameter = 'Directory'; Value = "/safe`r`nDELE other.txt" },
            @{ Function = 'Normalize-MvsDatasetPrefix'; Parameter = 'DatasetPrefix'; Value = "HLQ.DATA`r`nDELE OTHER" }
        )) {
            $caught = $null
            try {
                & $script:ModuleUnderTest {
                    param ($functionName, $parameterName, $value)
                    $parameters = @{}
                    $parameters[$parameterName] = $value
                    & $functionName @parameters
                } $case.Function $case.Parameter $case.Value
            }
            catch {
                $caught = $_
            }

            Assert-True -Condition ($null -ne $caught) -Message "$($case.Function) accepted a protocol line break."
        }
    }

    Invoke-RegressionTest -Name 'MVS location retries nonzero command results' -ScriptBlock {
        $fakeSession = [PSCustomObject]@{ Attempts = 0 }
        $fakeSession | Add-Member -MemberType ScriptMethod -Name ExecuteCommand -Value {
            param ($command)
            $this.Attempts++
            if ($this.Attempts -lt 3) {
                return [PSCustomObject]@{ ExitCode = 1; Output = 'temporary CWD failure' }
            }

            [PSCustomObject]@{ ExitCode = 0; Output = 'CWD succeeded' }
        }

        $remoteName = & $script:ModuleUnderTest {
            param ($session)
            Set-FtpsRemoteLocation `
                -Session $session `
                -HostDirectory 'HLQ.APP.DATA' `
                -RemoteFileName 'REPORT.TXT' `
                -MvsMode `
                -RetryCount 2 `
                -RetryDelaySeconds 0
        } $fakeSession

        Assert-Equal -Expected 'REPORT.TXT' -Actual $remoteName -Message 'The MVS remote name was not returned.'
        Assert-Equal -Expected 3 -Actual $fakeSession.Attempts -Message 'Nonzero MVS command results were not retried.'
    }

    Invoke-RegressionTest -Name 'MVS file checks query the target directly and preserve real failures' -ScriptBlock {
        & $script:ModuleUnderTest { Import-WinScpAssembly }
        # WinSCP creates remote exceptions internally, so use its nonpublic constructor
        # to exercise the real exception type and PowerShell method-call wrapping offline.
        $remoteExceptionConstructor = [WinSCP.SessionRemoteException].GetConstructor(
            [System.Reflection.BindingFlags]'Instance,NonPublic', $null,
            [type[]]@([WinSCP.Session], [string]), $null
        )
        $cases = @(
            @{ Name = 'present'; Error = $null; Exists = $true; Throws = $false; Mvs = $true },
            @{ Name = 'absent'; Error = $remoteExceptionConstructor.Invoke(@($null, "Cannot get attributes of file 'T001'.`r`nNo data sets found.")); Exists = $false; Throws = $false; Mvs = $true },
            @{ Name = 'absent with reply code'; Error = $remoteExceptionConstructor.Invoke(@($null, '550 No data sets found.')); Exists = $false; Throws = $false; Mvs = $true },
            @{ Name = 'permission denied'; Error = $remoteExceptionConstructor.Invoke(@($null, '550 Permission denied.')); Exists = $false; Throws = $true; Mvs = $true },
            @{ Name = 'connection lost'; Error = [System.TimeoutException]::new('Connection timed out.'); Exists = $false; Throws = $true; Mvs = $true },
            @{ Name = 'unrelated exception with same text'; Error = [System.InvalidOperationException]::new('No data sets found.'); Exists = $false; Throws = $true; Mvs = $true },
            @{ Name = 'ordinary FTP listing failure'; Error = $null; Exists = $false; Throws = $true; Mvs = $false }
        )
        foreach ($case in $cases) {
            $fakeSession = [PSCustomObject]@{
                Failure = $case.Error; Disposed = $false; MetadataCalls = 0
                ListCalls = 0; LastPath = $null; Command = $null
            }
            $fakeSession | Add-Member ScriptMethod Open { param ($options) }
            $fakeSession | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
            $fakeSession | Add-Member ScriptMethod ExecuteCommand {
                param ($command)
                $this.Command = $command
                [PSCustomObject]@{ ExitCode = 0; Output = 'CWD succeeded' }
            }
            $fakeSession | Add-Member ScriptMethod ListDirectory {
                param ($path)
                $this.ListCalls++
                throw 'Error listing directory.'
            }
            $fakeSession | Add-Member ScriptMethod GetFileInfo {
                param ($path)
                $this.MetadataCalls++
                $this.LastPath = $path
                if ($null -ne $this.Failure) { throw $this.Failure }
                [PSCustomObject]@{ Length = 123; LastWriteTime = [datetime]'2026-09-09'; IsDirectory = $false }
            }
            $caught = $null
            $result = $null
            try {
                $result = & $script:ModuleUnderTest {
                    param ($fakeSession, $mvsMode)
                    # These overrides live only in this invocation's local scope.
                    function New-FtpsSession { $fakeSession }
                    function New-FtpsSessionOptions { [PSCustomObject]@{} }
                    Test-FtpsRemoteFile -RemoteFileName 'T001' -HostDirectory 'HLQ.APP.DATA' `
                        -HostAddress 'offline.invalid' -Username 'test' -Password 'test' `
                        -MvsMode:$mvsMode -RetryCount 0 -RetryDelaySeconds 0
                } $fakeSession $case.Mvs
            }
            catch { $caught = $_ }

            Assert-Equal -Expected $case.Throws -Actual ($null -ne $caught) -Message "Unexpected failure state for $($case.Name): $caught"
            Assert-True -Condition $fakeSession.Disposed -Message "Session was not disposed for $($case.Name)."
            if ($case.Mvs) {
                Assert-Equal -Expected 0 -Actual $fakeSession.ListCalls -Message 'MVS file check attempted a directory listing.'
                Assert-Equal -Expected 'T001' -Actual $fakeSession.LastPath -Message 'MVS check did not query the relative target.'
                Assert-Equal -Expected "CWD 'HLQ.APP.DATA.'" -Actual $fakeSession.Command -Message 'MVS prefix was not selected.'
            }
            else {
                Assert-Equal -Expected 1 -Actual $fakeSession.ListCalls -Message 'Ordinary FTP no longer validates the directory.'
            }
            if (-not $case.Throws) {
                Assert-Equal -Expected $case.Exists -Actual $result.Exists -Message "Incorrect existence result for $($case.Name)."
                Assert-Equal -Expected 'T001' -Actual $result.RemotePath -Message 'Incorrect MVS result path.'
                if ($case.Exists) {
                    Assert-Equal -Expected 123 -Actual $result.Length -Message 'Existing file metadata was lost.'
                }
                else {
                    Assert-True -Condition ($null -eq $result.Length) -Message 'Missing file has unexpected metadata.'
                }
            }
        }
    }

    Invoke-RegressionTest -Name 'Normalize-TlsHostCertificateFingerprint accepts common SHA-256 forms' -ScriptBlock {
        $hex = '0011223344556677001122334455667700112233445566770011223344556677'
        $expected = '00:11:22:33:44:55:66:77:00:11:22:33:44:55:66:77:00:11:22:33:44:55:66:77:00:11:22:33:44:55:66:77'
        $cases = @(
            $hex,
            "SHA-256: $hex",
            "[$expected]"
        )

        foreach ($case in $cases) {
            $actual = & $script:ModuleUnderTest {
                param ($value)
                Normalize-TlsHostCertificateFingerprint -Fingerprint $value
            } $case

            Assert-Equal -Expected $expected -Actual $actual -Message "TLS fingerprint normalization failed for '$case'."
        }

        $multiple = & $script:ModuleUnderTest {
            param ($first, $second)
            Normalize-TlsHostCertificateFingerprint -Fingerprint "$first;$second"
        } $hex $expected

        Assert-Equal -Expected "$expected;$expected" -Actual $multiple -Message 'Multiple TLS fingerprints were not normalized independently.'

        $empty = & $script:ModuleUnderTest {
            Normalize-TlsHostCertificateFingerprint -Fingerprint '   '
        }
        Assert-True -Condition ($null -eq $empty) -Message 'A blank TLS fingerprint was not normalized to null.'
    }

    Invoke-RegressionTest -Name 'Configuration saves valid JSON and reloads the configured defaults' -ScriptBlock {
        $fingerprint = '00:11:22:33:44:55:66:77:00:11:22:33:44:55:66:77:00:11:22:33:44:55:66:77:00:11:22:33:44:55:66:77'

        Set-PSFtpsActionsSecurityDefault `
            -TlsMode Tls12Only `
            -TlsHostCertificateFingerprint $fingerprint | Out-Null

        Set-PSFtpsActionsConnectionDefault `
            -TimeoutSeconds 47 `
            -RetryCount 3 `
            -RetryDelaySeconds 0 | Out-Null

        $paths = Get-PSFtpsActionsStoragePath
        Assert-True -Condition (Test-Path -LiteralPath $paths.ConfigPath) -Message 'The configuration file was not created.'

        $rawConfig = Get-Content -LiteralPath $paths.ConfigPath -Raw
        $config = $rawConfig | ConvertFrom-Json
        Assert-Equal -Expected 'Tls12Only' -Actual $config.SecurityDefault.TlsMode -Message 'TlsMode was not serialized.'
        Assert-Equal -Expected $fingerprint -Actual $config.SecurityDefault.TlsHostCertificateFingerprint -Message 'The fingerprint was not serialized.'
        Assert-Equal -Expected 47 -Actual $config.ConnectionDefault.TimeoutSeconds -Message 'TimeoutSeconds was not serialized.'
        Assert-Equal -Expected 3 -Actual $config.ConnectionDefault.RetryCount -Message 'RetryCount was not serialized.'
        Assert-Equal -Expected 0 -Actual $config.ConnectionDefault.RetryDelaySeconds -Message 'RetryDelaySeconds was not serialized.'

        $unexpectedFiles = @(
            Get-ChildItem -LiteralPath (Split-Path -Parent $paths.ConfigPath) -File -Force |
                Where-Object { $_.FullName -ne $paths.ConfigPath }
        )
        Assert-Equal -Expected 0 -Actual $unexpectedFiles.Count -Message 'A completed configuration save left a temporary file behind.'

        Import-ModuleUnderTest
        $loadedSecurity = Get-PSFtpsActionsSecurityDefault
        $loadedConnection = Get-PSFtpsActionsConnectionDefault
        Assert-Equal -Expected 'Tls12Only' -Actual $loadedSecurity.TlsMode -Message 'TlsMode did not survive a module reload.'
        Assert-Equal -Expected $fingerprint -Actual $loadedSecurity.TlsHostCertificateFingerprint -Message 'The fingerprint did not survive a module reload.'
        Assert-Equal -Expected 47 -Actual $loadedConnection.TimeoutSeconds -Message 'TimeoutSeconds did not survive a module reload.'
        Assert-Equal -Expected 3 -Actual $loadedConnection.RetryCount -Message 'RetryCount did not survive a module reload.'
        Assert-Equal -Expected 0 -Actual $loadedConnection.RetryDelaySeconds -Message 'RetryDelaySeconds did not survive a module reload.'
    }

    Invoke-RegressionTest -Name 'A malformed configuration file does not prevent module import' -ScriptBlock {
        $paths = Get-PSFtpsActionsStoragePath
        $validConfig = Get-Content -LiteralPath $paths.ConfigPath -Raw
        $importFailure = $null

        try {
            Set-Content -LiteralPath $paths.ConfigPath -Value '{ invalid json' -Encoding UTF8
            try {
                Import-ModuleUnderTest
            }
            catch {
                $importFailure = $_
            }

            $importMessage = 'Malformed JSON prevented module import.'
            if ($null -ne $importFailure) {
                $importMessage += " $($importFailure.Exception.Message)"
            }
            Assert-True -Condition ($null -eq $importFailure) -Message $importMessage

            $defaults = Get-PSFtpsActionsConnectionDefault
            Assert-Equal -Expected 30 -Actual $defaults.TimeoutSeconds -Message 'Malformed configuration did not leave the built-in timeout default intact.'
            Assert-Equal -Expected 0 -Actual $defaults.RetryCount -Message 'Malformed configuration did not leave the built-in retry-count default intact.'
            Assert-Equal -Expected 5 -Actual $defaults.RetryDelaySeconds -Message 'Malformed configuration did not leave the built-in retry-delay default intact.'
        }
        finally {
            Set-Content -LiteralPath $paths.ConfigPath -Value $validConfig -Encoding UTF8
            Import-ModuleUnderTest
        }
    }

    Invoke-RegressionTest -Name 'Named credentials survive a module reload in the isolated store' -ScriptBlock {
        $securePassword = ConvertTo-SecureString -String 'regression-only-password' -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential('regression-user', $securePassword)
        $saved = Set-PSFtpsCredential -Name 'regression-ftps' -Credential $credential

        Assert-True -Condition (Test-Path -LiteralPath $saved.Path) -Message 'The named credential file was not created.'

        $replacementPassword = ConvertTo-SecureString -String 'replacement-regression-password' -AsPlainText -Force
        $replacementCredential = New-Object System.Management.Automation.PSCredential('replacement-user', $replacementPassword)
        Set-PSFtpsCredential -Name 'regression-ftps' -Credential $replacementCredential | Out-Null

        $credentialDirectory = Split-Path -Parent $saved.Path
        $unexpectedFiles = @(
            Get-ChildItem -LiteralPath $credentialDirectory -File -Force |
                Where-Object { $_.FullName -ne $saved.Path }
        )
        Assert-Equal -Expected 0 -Actual $unexpectedFiles.Count -Message 'A completed credential save left a temporary file behind.'

        Import-ModuleUnderTest
        $loaded = Get-PSFtpsCredential -Name 'regression-ftps' -IncludeCredential
        Assert-Equal -Expected 'replacement-user' -Actual $loaded.Username -Message 'The replacement username did not survive a module reload.'
        Assert-Equal -Expected 'replacement-regression-password' -Actual $loaded.Credential.GetNetworkCredential().Password -Message 'The replacement password did not survive a module reload.'
    }

    Invoke-RegressionTest -Name 'Specific-file transfers do not use unescaped remote masks for deletion' -ScriptBlock {
        $removeSource = Get-Content -LiteralPath (Join-Path $repoRoot 'Public\Remove-FtpsFile.ps1') -Raw
        $downloadSource = Get-Content -LiteralPath (Join-Path $repoRoot 'Public\Get-FtpsFile.ps1') -Raw

        Assert-True -Condition ($removeSource -notmatch '\.RemoveFiles\s*\(') -Message 'Remove-FtpsFile still calls the mask-based RemoveFiles API.'
        Assert-True -Condition ($downloadSource -notmatch '\.RemoveFiles\s*\(') -Message 'Get-FtpsFile still calls the mask-based RemoveFiles API.'
        Assert-True -Condition ($downloadSource -match 'RemotePath\]::EscapeFileMask') -Message 'Get-FtpsFile does not escape its specific remote file path before GetFiles.'
    }

    Invoke-RegressionTest -Name 'Transfer commands expose the intended transfer modes with an ASCII-compatible default' -ScriptBlock {
        foreach ($commandName in @('Send-FtpsFile', 'Get-FtpsFile')) {
            $command = Get-Command -Name $commandName -Module PSFtpsActions
            Assert-True -Condition $command.Parameters.ContainsKey('TransferMode') -Message "$commandName does not expose TransferMode."

            $validateSet = @(
                $command.Parameters['TransferMode'].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            ) | Select-Object -First 1

            Assert-True -Condition ($null -ne $validateSet) -Message "$commandName TransferMode does not have a ValidateSet."
            Assert-SetEqual -Expected @('Ascii', 'Binary', 'Automatic') -Actual @($validateSet.ValidValues) -Message "$commandName has unexpected transfer modes."

            $defaultValue = Get-FunctionParameterDefaultValue -Command $command -ParameterName 'TransferMode'
            Assert-Equal -Expected 'Ascii' -Actual $defaultValue -Message "$commandName changed its backward-compatible transfer-mode default."
        }
    }

    Invoke-RegressionTest -Name 'JAMS-compatible Username and Password string parameters remain available' -ScriptBlock {
        $commandNames = @(
            'Send-FtpsFile',
            'Get-FtpsFile',
            'Get-FtpsChildItem',
            'Remove-FtpsFile',
            'Test-FtpsRemoteFile',
            'Test-FtpsConnection'
        )

        foreach ($commandName in $commandNames) {
            $command = Get-Command -Name $commandName -Module PSFtpsActions
            Assert-True -Condition $command.Parameters.ContainsKey('Username') -Message "$commandName no longer exposes Username."
            Assert-True -Condition $command.Parameters.ContainsKey('Password') -Message "$commandName no longer exposes Password."
            Assert-Equal -Expected ([string]) -Actual $command.Parameters['Username'].ParameterType -Message "$commandName Username changed type."
            Assert-Equal -Expected ([string]) -Actual $command.Parameters['Password'].ParameterType -Message "$commandName Password changed type."
        }
    }

    Invoke-RegressionTest -Name 'Mutating commands support ShouldProcess and offline WhatIf' -ScriptBlock {
        foreach ($commandName in @('Send-FtpsFile', 'Get-FtpsFile', 'Remove-FtpsFile', 'Remove-PSFtpsCredential')) {
            $command = Get-Command -Name $commandName -Module PSFtpsActions
            Assert-True -Condition $command.Parameters.ContainsKey('WhatIf') -Message "$commandName does not expose WhatIf."
            Assert-True -Condition $command.Parameters.ContainsKey('Confirm') -Message "$commandName does not expose Confirm."
        }

        $whatIfUploadPath = Join-Path $testRoot 'whatif-upload.txt'
        Set-Content -LiteralPath $whatIfUploadPath -Value 'offline WhatIf content' -NoNewline

        Send-FtpsFile `
            -FilePath $whatIfUploadPath `
            -RemoteFileName 'whatif.txt' `
            -Username 'regression-user' `
            -Password 'regression-password' `
            -HostAddress '127.0.0.1' `
            -Port 1 `
            -HostDirectory '/' `
            -TimeoutSeconds 1 `
            -WhatIf | Out-Null

        Get-FtpsFile `
            -RemoteFileName 'whatif.txt' `
            -LocalDirectory $testRoot `
            -Username 'regression-user' `
            -Password 'regression-password' `
            -HostAddress '127.0.0.1' `
            -Port 1 `
            -HostDirectory '/' `
            -TimeoutSeconds 1 `
            -WhatIf | Out-Null

        Remove-FtpsFile `
            -RemoteFileName 'whatif.txt' `
            -Username 'regression-user' `
            -Password 'regression-password' `
            -HostAddress '127.0.0.1' `
            -Port 1 `
            -HostDirectory '/' `
            -TimeoutSeconds 1 `
            -WhatIf | Out-Null

        Remove-PSFtpsCredential -Name 'regression-ftps' -WhatIf
        Assert-True -Condition ($null -ne (Get-PSFtpsCredential -Name 'regression-ftps')) -Message 'Remove-PSFtpsCredential -WhatIf removed the credential.'
    }
}
finally {
    Remove-Module -Name PSFtpsActions -Force -ErrorAction SilentlyContinue
    $env:APPDATA = $originalAppData

    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $resolvedTempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $testLeaf = Split-Path -Leaf $resolvedTestRoot
    $isSafeTestPath = $resolvedTestRoot.StartsWith($resolvedTempRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        $testLeaf.StartsWith('PSFtpsActions_Regression_', [System.StringComparison]::Ordinal)

    if ((Test-Path -LiteralPath $resolvedTestRoot) -and $isSafeTestPath) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

Write-Host ''
Write-Host "Regression tests passed: $script:PassedCount"
Write-Host "Regression tests failed: $($script:Failures.Count)"

if ($script:Failures.Count -gt 0) {
    $failureSummary = ($script:Failures | ForEach-Object { "$($_.Name): $($_.Message)" }) -join [Environment]::NewLine
    throw "PSFtpsActions regression tests failed.$([Environment]::NewLine)$failureSummary"
}

Write-Host 'PSFtpsActions offline regression tests passed.' -ForegroundColor Green
