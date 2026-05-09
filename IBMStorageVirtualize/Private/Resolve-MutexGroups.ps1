function Build-ConflictGraph {
    param(
        [hashtable]$Rules
    )

    $graph = @{}

    foreach ($rule in $Rules.Values) {
        $set = $rule | ForEach-Object { $_.ToLower() }

        foreach ($a in $set) {
            if (-not $graph.ContainsKey($a)) { $graph[$a] = @{} }
            foreach ($b in $set) {
                if ($a -ne $b) {
                    $graph[$a][$b] = $true
                }
            }
        }
    }
    return $graph
}

function Test-PropCompatibility {
    param(
        [hashtable]$Bin,

        [string]$Prop,

        [hashtable]$Graph
    )

    $p = $Prop.ToLower()

    if (-not $Graph.ContainsKey($p)) { return $true }

    foreach ($k in $Bin.Keys) {
        if ($Graph[$p].ContainsKey($k)) { return $false }
    }

    return $true
}

function Test-UnitCompatibility {
    param(
        [hashtable]$Bin,

        [hashtable]$Unit,

        [hashtable]$Graph
    )

    foreach ($p in $Unit.Keys) {
        if (-not (Test-PropCompatibility -Bin $Bin -Prop $p -Graph $Graph)) {
            return $false
        }
    }

    return $true
}

function Join-DependencyUnit {
    param(
        [hashtable]$Props,

        [hashtable]$Dependencies
    )

    $units = @()

    foreach ($child in $Dependencies.Keys) {

        $c = $child.ToLower()
        if (-not $Props.ContainsKey($c)) { continue }

        $parents = $Dependencies[$child] | ForEach-Object { $_.ToLower() }
        $members = @($c) + $parents | Where-Object { $Props.ContainsKey($_) }

        $merged = $false

        foreach ($u in $units) {
            if ($members | Where-Object { $u.ContainsKey($_) }) {
                foreach ($m in $members) {
                    $u[$m] = $Props[$m]
                }
                $merged = $true
                break
            }
        }

        if (-not $merged) {
            $unit = @{}
            foreach ($m in $members) {
                $unit[$m] = $Props[$m]
            }
            $units += ,$unit
        }
    }

    foreach ($k in $Props.Keys) {
        if (-not ($units | Where-Object { $_.ContainsKey($k) })) {
            $units += ,@{ $k = $Props[$k] }
        }
    }

    return $units
}

function Resolve-MutexGroup {
    param(
        [hashtable]$Props,

        [hashtable]$Rules,

        [hashtable]$Dependencies
    )

    $norm = @{}
    foreach ($k in $Props.Keys) {
        $norm[$k.ToLower()] = $Props[$k]
    }

    $Graph = Build-ConflictGraph -Rules $Rules

    $Units = Join-DependencyUnit -Props $norm -Dependencies $Dependencies


    $Units = $Units | Sort-Object {
        $u = $_
        $score = 0
        foreach ($k in $u.Keys) {
            if ($Graph.ContainsKey($k)) {
                $score += $Graph[$k].Count
            }
        }
        -$score
    }

    $Bins = @()

    foreach ($unit in $Units) {
        $placed = $false

        foreach ($bin in $Bins) {
            if (Test-UnitCompatibility -Bin $bin -Unit $unit -Graph $Graph) {
                foreach ($k in $unit.Keys) {
                    $bin[$k] = $unit[$k]
                }
                $placed = $true
                break
            }
        }

        if (-not $placed) {
            $Bins += ,([hashtable]$unit.Clone())
        }
    }

    return $Bins
}
