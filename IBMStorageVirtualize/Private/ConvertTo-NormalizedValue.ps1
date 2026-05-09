function ConvertTo-NormalizedValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Separator,
        [string]$Case = "None"
    )

    $items = $Value.Split($Separator) |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -ne "" }

    switch ($Case.ToLower()) {
        "upper" { $items = $items | ForEach-Object { $_.ToUpper() } }
        "lower" { $items = $items | ForEach-Object { $_.ToLower() } }
    }

    $dup = $items | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($dup) {
        $d = $dup | ForEach-Object { $_.Name }
        return [pscustomobject]@{ err = "Duplicate $Name values found: $($d -join ', ')" }
    }

    return [pscustomobject]@{ out = $items -join $Separator }
}
