function Get-IBMSVVersion {
    [CmdletBinding()]
    param(
        [string]$Cluster
    )

    $session = if ($Cluster) {
        if (-not $script:sessions.ContainsKey($Cluster)) {
            return [pscustomobject]@{ err = "No session found for cluster $Cluster." }
        }
        $script:sessions[$Cluster]
    }
    else {
        if (-not $script:primarysession) {
            return [pscustomobject]@{ err = "No primary session found. Specify -Cluster or reconnect using Connect-IBMStorageVirtualize -Primary." }
        }
        $script:sessions[$script:primarysession]
    }

    if (-not $session.SVCVersion) {
        $result = Invoke-IBMSVRestRequest -Cluster $session.Cluster -Cmd "lssystem" | Out-Null
        if ($result.err) { return $result }
    }

    return $script:sessions[$session.Cluster].SVCVersion
}
