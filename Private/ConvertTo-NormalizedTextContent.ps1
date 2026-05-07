<#
.SYNOPSIS
Normalizes text content before upload.

.DESCRIPTION
Optionally trims spaces and tabs from the end of each line and converts line endings to a requested sequence. When no line ending is supplied, existing line-ending sequences are preserved.
#>
function ConvertTo-NormalizedTextContent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $false)]
        [switch]$TrimTrailingWhitespace,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string]$LineEnding
    )

    if (-not $TrimTrailingWhitespace -and [string]::IsNullOrEmpty($LineEnding)) {
        return $Content
    }

    $matches = [regex]::Matches($Content, '(?<Line>.*?)(?<Ending>\r\n|\n|\r|$)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $builder = New-Object System.Text.StringBuilder

    foreach ($match in $matches) {
        if ($match.Length -eq 0) {
            continue
        }

        $line = $match.Groups['Line'].Value
        $ending = $match.Groups['Ending'].Value

        if ($TrimTrailingWhitespace) {
            $line = $line -replace '[ \t]+$', ''
        }

        [void]$builder.Append($line)

        if ($ending.Length -gt 0) {
            if ([string]::IsNullOrEmpty($LineEnding)) {
                [void]$builder.Append($ending)
            }
            else {
                [void]$builder.Append($LineEnding)
            }
        }
    }

    return $builder.ToString()
}
