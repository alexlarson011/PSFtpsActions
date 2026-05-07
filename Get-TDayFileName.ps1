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