<#
.SYNOPSIS
Builds a T-day style file name from a date.

.DESCRIPTION
Returns a string made from a prefix plus the day-of-year value for a date. The day number is left padded to the requested width. By default, May 7 returns T127 in a non-leap year.

.PARAMETER Date
Date used to calculate the day-of-year value. Defaults to the current date.

.PARAMETER Prefix
Prefix to place before the padded day number. Defaults to T.

.PARAMETER PadLength
Minimum width of the day number. Defaults to 3.

.EXAMPLE
Get-TDayFileName -Date '2026-05-07'

Returns T127.

.EXAMPLE
Get-TDayFileName -Date '2026-01-05' -Prefix 'D' -PadLength 4

Returns D0005.
#>
function Get-TDayFileName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [datetime]$Date = (Get-Date),

        [Parameter(Mandatory = $false)]
        [string]$Prefix = 'T',

        [Parameter(Mandatory = $false)]
        [int]$PadLength = 3
    )

    $dayOfYear = $Date.DayOfYear
    $dayText = $dayOfYear.ToString().PadLeft($PadLength, '0')

    return "$Prefix$dayText"
}
