$SensitiveKeys = @(
    'password', 'siapikey', 'hostsecret', 'storagesecret', 'licensekey', 'chapsecret',
    'pass', 'secret', 'token', 'key', 'apikey', 'api_key',
    'authorization', 'auth', 'credential', 'privatekey'
)

function ConvertTo-SafeObject {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [string] -or $InputObject.GetType().IsValueType) {
        return $InputObject
    }

    if ($InputObject -is [hashtable] -or $InputObject -is [System.Collections.IDictionary]) {
        $copy = @{}
        foreach ($k in $InputObject.Keys) {
            if ($SensitiveKeys -contains $k.ToString().ToLower()) {
                $copy[$k] = '########'
            }
            else {
                $copy[$k] = ConvertTo-SafeObject -InputObject $InputObject[$k]
            }
        }
        return $copy
    }

    if ($InputObject -is [pscustomobject]) {
        $copy = [ordered]@{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            if ($SensitiveKeys -contains $prop.Name.ToLower()) {
                $copy[$prop.Name] = '########'
            }
            else {
                $copy[$prop.Name] = ConvertTo-SafeObject -InputObject $prop.Value
            }
        }
        return [pscustomobject]$copy
    }

    if ($InputObject -is [System.Collections.IEnumerable]) {
        return @(
            foreach ($item in $InputObject) {
                ConvertTo-SafeObject -InputObject $item
            }
        )
    }

    return $InputObject
}
