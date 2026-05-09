function ConvertTo-Byte {
    param(
        [Parameter(Mandatory)]
        [int64]$Size,

        [Parameter(Mandatory)]
        [ValidateSet('b', 'kb', 'mb', 'gb', 'tb', 'pb')]
        [string]$Unit
    )

    $byteMultipliers = @{
        'b'  = 1
        'kb' = 1024
        'mb' = 1048576
        'gb' = 1073741824
        'tb' = 1099511627776
        'pb' = 1125899906842624
    }

    return [int64]$Size * $byteMultipliers[$Unit.ToLower()]
}
