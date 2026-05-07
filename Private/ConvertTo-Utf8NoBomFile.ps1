<#
.SYNOPSIS
Creates a normalized text-file copy using UTF-8 without BOM.

.DESCRIPTION
Reads a source text file using BOM detection when available and writes the content to a destination file using UTF-8 encoding without a byte order mark. Can trim trailing spaces and tabs from each line and normalize line endings. The source file is not modified.
#>
function ConvertTo-Utf8NoBomFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $false)]
        [switch]$TrimTrailingWhitespace,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Preserve', 'Windows', 'Unix')]
        [string]$LineEnding = 'Preserve'
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "Source file not found: $SourcePath"
    }

    $destinationDirectory = Split-Path -Parent $DestinationPath
    if (-not [string]::IsNullOrWhiteSpace($destinationDirectory) -and -not (Test-Path -LiteralPath $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    $reader = $null
    $writer = $null

    try {
        $reader = New-Object System.IO.StreamReader -ArgumentList $SourcePath, $true
        $content = $reader.ReadToEnd()

        if ($TrimTrailingWhitespace -or $LineEnding -ne 'Preserve') {
            $lineEndingText = switch ($LineEnding) {
                'Windows' { "`r`n" }
                'Unix' { "`n" }
                'Preserve' { $null }
            }

            $content = ConvertTo-NormalizedTextContent `
                -Content $content `
                -TrimTrailingWhitespace:$TrimTrailingWhitespace `
                -LineEnding $lineEndingText
        }

        $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
        $writer = New-Object System.IO.StreamWriter -ArgumentList $DestinationPath, $false, $utf8NoBom
        $writer.Write($content)
    }
    finally {
        if ($reader) {
            $reader.Dispose()
        }

        if ($writer) {
            $writer.Dispose()
        }
    }

    return Get-Item -LiteralPath $DestinationPath
}
