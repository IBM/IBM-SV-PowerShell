Describe "New-IBMSVTruststore Tests" {
    BeforeEach {
        $script:LsTruststoreCalls = 0
        $script:callCount = 0
        $script:tmpCallCount = 0

        Mock Get-IBMSVVersion { return "9.1.0.0" } -ModuleName IBMStorageVirtualize

        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdArgs)

            if ($Cmd -eq "lstruststore") {
                $script:LsTruststoreCalls++
                if ($script:LsTruststoreCalls -eq 1) {
                    return $null
                }
                elseif ($script:LsTruststoreCalls -eq 2) {
                    return [pscustomobject]@{
                        id = '1'
                        name = $CmdArgs
                    }
                }
                elseif ($script:LsTruststoreCalls -eq 3) {
                    return $null
                }
                return [pscustomobject]@{
                    id = '1'
                    name = $CmdArgs
                }
            }

            $script:callCount++
            if ($Cmd -eq "lssystemcertstore") {
                return [pscustomobject]@{
                    id = '1'
                    scope = 'internal_communication'
                }
            }

            if ($Cmd -eq "chsystemcertstore" -or $Cmd -eq "chsystemcert") {
                return $null
            }

            if ($Cmd -eq "mktruststore") {
                return [pscustomobject]@{
                    id = '1'
                    message = 'Truststore created successfully'
                }
            }
        } -ModuleName IBMStorageVirtualize

        Mock Copy-IBMSVCertificateViaSCP {
            return @{
                Success = $true
                Error = $null
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to create volume when -WhatIf is specified" {
        New-IBMSVTruststore -Name "pwsh_ts0" -RemoteCluster "10.10.10.20" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should create truststores while exporting internal_communication certificate for version 9.1.0.0+ and use same name when remote truststore name is not specified" {
        $result = New-IBMSVTruststore -Name "pwsh_ts0" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10"
        $result[0].id | Should -Be 1
        $result[0].name | Should -Be "pwsh_ts0"
        $result[1].id | Should -Be 1
        $result[1].name | Should -Be "pwsh_ts0"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts0"}

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssystemcertstore" -and $CmdArgs -contains "internal_communication" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chsystemcertstore" -and $CmdOpts.exportrootca -eq $true -and $CmdOpts.scope -eq "internal_communication" }

        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.20" -and $TargetCluster -eq "10.10.10.10" -and $CertFile -eq "system_rootcacertificate_slot_3.pem" -and $TargetCertFile -like "system_rootcacertificate_slot_3_*.pem" }

        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.10" -and $TargetCluster -eq "10.10.10.20" -and $CertFile -eq "system_rootcacertificate_slot_3.pem" -and $TargetCertFile -like "system_rootcacertificate_slot_3_*.pem" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/system_rootcacertificate_slot_3_*.pem" -and $CmdOpts.name -eq "pwsh_ts0" -and $CmdOpts.grid -eq "on" }
    }

    It "Should create truststores while exporting default certificate when internal_communication doesn't exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdArgs)
            $script:callCount++
            if ($Cmd -eq "lstruststore") {
                $script:LsTruststoreCalls++
                if ($script:LsTruststoreCalls -eq 1) {
                    return $null
                }
                elseif ($script:LsTruststoreCalls -eq 2) {
                    return [pscustomobject]@{
                        id = '1'
                        name = $CmdArgs
                    }
                }
                elseif ($script:LsTruststoreCalls -eq 3) {
                    return $null
                }
                return [pscustomobject]@{
                    id = '1'
                    name = $CmdArgs
                }
            }
            if ($Cmd -eq "lssystemcertstore") {
                return $null
            }
            if ($Cmd -eq "chsystemcert") {
                return $null
            }
            if ($Cmd -eq "mktruststore") {
                return [pscustomobject]@{
                    id = '1'
                    name = $CmdArgs
                }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10"
        $result[0].id | Should -Be 1
        $result[0].name | Should -Be "pwsh_ts0"
        $result[1].id | Should -Be 1
        $result[1].name | Should -Be "pwsh_ts1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lstruststore" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssystemcertstore" -and $CmdArgs -contains "internal_communication" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chsystemcertstore" -and $CmdOpts.exportrootca -eq $true -and $CmdOpts.scope -eq "default" }

        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.20" -and $TargetCluster -eq "10.10.10.10" -and $CertFile -eq "rootcacertificate.pem" -and $TargetCertFile -like "rootcacertificate_10_10_10_20_*.pem" }

        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.10" -and $TargetCluster -eq "10.10.10.20" -and $CertFile -eq "rootcacertificate.pem" -and $TargetCertFile -like "rootcacertificate_10_10_10_10_*.pem" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/rootcacertificate_*.pem" -and $CmdOpts.name -eq "pwsh_ts0" -and $CmdOpts.grid -eq "on" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/rootcacertificate_*.pem" -and $CmdOpts.name -eq "pwsh_ts1" -and $CmdOpts.grid -eq "on" }
    }

    It "Should create truststores while exporting grid root CA certificate for version 8.7.3.0" {
        Mock Get-IBMSVVersion {
            return "8.7.3.0"
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10"
        $result[0].id | Should -Be 1
        $result[0].name | Should -Be "pwsh_ts0"
        $result[1].id | Should -Be 1
        $result[1].name | Should -Be "pwsh_ts1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lstruststore" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chsystemcert" -and $CmdOpts.exportrootcacert -eq $true }

        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.20" -and $TargetCluster -eq "10.10.10.10" -and $CertFile -eq "rootcacertificate.pem" -and $TargetCertFile -like "rootcacertificate_10_10_10_20_*.pem" }

        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.10" -and $TargetCluster -eq "10.10.10.20" -and $CertFile -eq "rootcacertificate.pem" -and $TargetCertFile -like "rootcacertificate_10_10_10_10_*.pem" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/rootcacertificate_*.pem" -and $CmdOpts.name -eq "pwsh_ts0" -and $CmdOpts.flashgrid -eq "on" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/rootcacertificate_*.pem" -and $CmdOpts.name -eq "pwsh_ts1" -and $CmdOpts.flashgrid -eq "on" }
    }

    It "Should create truststores while exporting legacy REST API certificate for version 8.7.0.0-8.7.2.x" {
        Mock Get-IBMSVVersion {
            return "8.7.1.0"
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10"
        $result[0].id | Should -Be 1
        $result[0].name | Should -Be "pwsh_ts0"
        $result[1].id | Should -Be 1
        $result[1].name | Should -Be "pwsh_ts1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lstruststore" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chsystemcert" -and $CmdOpts.export -eq $true }

        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.20" -and $TargetCluster -eq "10.10.10.10" -and $CertFile -eq "certificate.pem" -and $TargetCertFile -like "certificate_10_10_10_20_*.pem" }

        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.10" -and $TargetCluster -eq "10.10.10.20" -and $CertFile -eq "certificate.pem" -and $TargetCertFile -like "certificate_10_10_10_10_*.pem" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/certificate_*.pem" -and $CmdOpts.name -eq "pwsh_ts0" -and $CmdOpts.restapi -eq "on" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/certificate_*.pem" -and $CmdOpts.name -eq "pwsh_ts1" -and $CmdOpts.restapi -eq "on" }
    }

    It "Should create truststores when local cluster is 8.7.0.0 and remote cluster is 8.7.3.0"{
        Mock Get-IBMSVVersion {
            $script:tmpCallCount++
            if ($script:tmpCallCount -eq 1) {
                return "8.7.0.0"
            }
            else {
                return "8.7.3.0"
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10"
        $result[0].id | Should -Be 1
        $result[0].name | Should -Be "pwsh_ts0"
        $result[1].id | Should -Be 1
        $result[1].name | Should -Be "pwsh_ts1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lstruststore" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssystemcertstore" -and $CmdArgs -contains "internal_communication" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "chsystemcert" -and $CmdOpts.exportrootcacert -eq $true }
        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.20" -and $TargetCluster -eq "10.10.10.10" -and $CertFile -eq "rootcacertificate.pem" -and $TargetCertFile -like "rootcacertificate_10_10_10_20_*.pem" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.10" -and $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/rootcacertificate_10_10_10_20_*.pem" -and $CmdOpts.name -eq "pwsh_ts0" -and $CmdOpts.restapi -eq "on" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.10" -and $Cmd -eq "chsystemcert" -and $CmdOpts.export -eq $true}
        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.10" -and $TargetCluster -eq "10.10.10.20" -and $CertFile -eq "certificate.pem" -and $TargetCertFile -like "certificate_10_10_10_10_*.pem" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/certificate_10_10_10_10_*.pem" -and $CmdOpts.name -eq "pwsh_ts1" -and $CmdOpts.restapi -eq "on" }
    }

    It "Should create truststores when local cluster is 8.7.0.0 and remote cluster is 9.1.0.0"{
        Mock Get-IBMSVVersion {
            $script:tmpCallCount++
            if ($script:tmpCallCount -eq 1) {
                return "8.7.0.0"
            }
            else {
                return "9.1.0.0"
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10"
        $result[0].id | Should -Be 1
        $result[0].name | Should -Be "pwsh_ts0"
        $result[1].id | Should -Be 1
        $result[1].name | Should -Be "pwsh_ts1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lstruststore" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "lssystemcertstore" -and $CmdArgs -contains "internal_communication" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "chsystemcertstore" -and $CmdOpts.exportrootca -eq $true -and $CmdOpts.scope -eq "internal_communication" }
        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.20" -and $TargetCluster -eq "10.10.10.10" -and $CertFile -eq "system_rootcacertificate_slot_3.pem" -and $TargetCertFile -like "system_rootcacertificate_slot_3_10_10_10_20_*.pem" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.10" -and $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/system_rootcacertificate_slot_3_10_10_10_20_*.pem" -and $CmdOpts.name -eq "pwsh_ts0" -and $CmdOpts.restapi -eq "on" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.10" -and $Cmd -eq "lssystemcertstore" -and $CmdArgs -contains "internal_communication" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.10" -and $Cmd -eq "chsystemcert" -and $CmdOpts.export -eq $true}
        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.10" -and $TargetCluster -eq "10.10.10.20" -and $CertFile -eq "certificate.pem" -and $TargetCertFile -like "certificate_10_10_10_10_*.pem" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/certificate_10_10_10_10_*.pem" -and $CmdOpts.name -eq "pwsh_ts1" -and $CmdOpts.restapi -eq "on" }
    }

    It "Should create truststores when local cluster is 8.7.3.0 and remote cluster is 9.1.0.0"{
        Mock Get-IBMSVVersion {
            $script:tmpCallCount++
            if ($script:tmpCallCount -eq 1) {
                return "8.7.3.0"
            }
            else {
                return "9.1.0.0"
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10"
        $result[0].id | Should -Be 1
        $result[0].name | Should -Be "pwsh_ts0"
        $result[1].id | Should -Be 1
        $result[1].name | Should -Be "pwsh_ts1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lstruststore"}

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "lssystemcertstore" -and $CmdArgs -contains "internal_communication" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "chsystemcertstore" -and $CmdOpts.exportrootca -eq $true -and $CmdOpts.scope -eq "internal_communication" }
        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.20" -and $TargetCluster -eq "10.10.10.10" -and $CertFile -eq "system_rootcacertificate_slot_3.pem" -and $TargetCertFile -like "system_rootcacertificate_slot_3_10_10_10_20_*.pem" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.10" -and $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/system_rootcacertificate_slot_3_10_10_10_20_*.pem" -and $CmdOpts.name -eq "pwsh_ts0" -and $CmdOpts.flashgrid -eq "on" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.10" -and $Cmd -eq "lssystemcertstore" -and $CmdArgs -contains "internal_communication" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.10" -and $Cmd -eq "chsystemcert" -and $CmdOpts.exportrootcacert -eq $true}
        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.10" -and $TargetCluster -eq "10.10.10.20" -and $CertFile -eq "rootcacertificate.pem" -and $TargetCertFile -like "rootcacertificate_10_10_10_10_*.pem" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/rootcacertificate_10_10_10_10_*.pem" -and $CmdOpts.name -eq "pwsh_ts1" -and $CmdOpts.grid -eq "on" }
    }

    It "Should create truststore on remote cluster only when already exists on local cluster" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdArgs)

            $script:callCount++

            if ($Cmd -eq "lstruststore") {
                if ($script:callCount -eq 1) {
                    return [pscustomobject]@{
                        id = '1'
                        name = $CmdArgs
                    }
                }
                elseif ($script:callCount -eq 2) {
                    return $null
                }
                return [pscustomobject]@{
                    id = '1'
                    name = $CmdArgs
                }
            }

            if ($Cmd -eq "lssystemcertstore") {
                return $null
            }

            if ($Cmd -eq "chsystemcertstore") {
                return $null
            }

            if ($Cmd -eq "mktruststore") {
                return [pscustomobject]@{
                    id = '1'
                    name = $CmdArgs
                }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10"
        $result[0].id | Should -Be 1
        $result[0].name | Should -Be "pwsh_ts0"
        $result[1].id | Should -Be 1
        $result[1].name | Should -Be "pwsh_ts1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lstruststore" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssystemcertstore" -and $CmdArgs -contains "internal_communication" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chsystemcertstore" -and $CmdOpts.exportrootca -eq $true -and $CmdOpts.scope -eq "default" }

        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $SourceCluster -eq "10.10.10.10" -and $TargetCluster -eq "10.10.10.20" -and $CertFile -eq "rootcacertificate.pem" -and $TargetCertFile -like "rootcacertificate_10_10_10_10_*.pem" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cluster -eq "10.10.10.20" -and $Cmd -eq "mktruststore" -and $CmdOpts.file -like "/tmp/rootcacertificate_*.pem" -and $CmdOpts.name -eq "pwsh_ts1" -and $CmdOpts.grid -eq "on" }
    }

    It "Should be idempotent when truststore already exists" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdArgs)

            if ($Cmd -eq "lstruststore") {
                return [pscustomobject]@{
                    id = '1'
                    name = $CmdArgs
                }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVTruststore -Name "pwsh_ts0" -RemoteTruststoreName "pwsh_ts1" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10"
        $result[0].id | Should -Be 1
        $result[0].name | Should -Be "pwsh_ts0"
        $result[1].id | Should -Be 1
        $result[1].name | Should -Be "pwsh_ts1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lstruststore" -and $CmdArgs -eq "pwsh_ts1" }

        Assert-MockCalled Copy-IBMSVCertificateViaSCP -Times 0 -ModuleName IBMStorageVirtualize

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -in @('lssystemcertstore', 'chsystemcert', 'mktruststore') }
    }

    It "Should throw error when certificate transfer fails" {
        Mock Copy-IBMSVCertificateViaSCP {
            return @{
                Success = $false
                Error = "Authentication failed while transferring the certificate via SCP."
            }
        } -ModuleName IBMStorageVirtualize

        { New-IBMSVTruststore -Name "pwsh_ts0" -RemoteCluster "10.10.10.20" -Cluster "10.10.10.10" } | Should -Throw "Authentication failed while transferring the certificate via SCP."
    }
}

Describe "Copy-IBMSVCertificateViaSCP Auth Tests" {
    BeforeAll {
        $script:pwsh_cred = New-Object System.Management.Automation.PSCredential (
            "pwsh_user",
            (ConvertTo-SecureString "pwsh_pass" -AsPlainText -Force)
        )

        Mock New-IBMSVSshSession {
            return [SSH.SshSession]::new()
        } -ModuleName IBMStorageVirtualize

        Mock New-SSHShellStream {
            $stream = [pscustomobject]@{}
            $stream | Add-Member -MemberType ScriptMethod -Name WriteLine -Value {}
            $stream | Add-Member -MemberType ScriptMethod -Name Read -Value {
                return "system_rootcacertificate_slot_3.pem 100%"
            }
            $stream | Add-Member -MemberType ScriptMethod -Name Dispose -Value {}
            $stream | Add-Member -MemberType NoteProperty -Name DataAvailable -Value $true
            return $stream
        } -ModuleName IBMStorageVirtualize

        Mock Remove-SSHSession {} -ModuleName IBMStorageVirtualize
    }

    Context "Credential path - AllowCredentialCaching" {
        It "Should resolve credential from session.Credential and succeed" {
            InModuleScope IBMStorageVirtualize -Parameters @{ cred = $script:pwsh_cred } {
                $script:sessions = @{
                    "10.10.10.10" = @{ Cluster = "10.10.10.10"; Credential = $cred; SecretName = $null; VaultName = $null }
                    "10.10.10.20" = @{ Cluster = "10.10.10.20"; Credential = $cred; SecretName = $null; VaultName = $null }
                }
            }

            $result = InModuleScope IBMStorageVirtualize {
                Copy-IBMSVCertificateViaSCP -SourceCluster "10.10.10.10" -TargetCluster "10.10.10.20" `
                    -CertFile "system_rootcacertificate_slot_3.pem" -TargetCertFile "system_rootcacertificate_slot_3_20250101_120000.pem"
            }

            $result.Success | Should -Be $true
            Assert-MockCalled New-IBMSVSshSession -Times 1 -ModuleName IBMStorageVirtualize
        }
    }

    Context "Credential path - SecretName (default vault)" {
        It "Should call Get-Secret and succeed when SecretName is set without VaultName" {
            InModuleScope IBMStorageVirtualize -Parameters @{ cred = $script:pwsh_cred } {
                $script:sessions = @{
                    "10.10.10.10" = @{ Cluster = "10.10.10.10"; Credential = $null; SecretName = "my-secret"; VaultName = $null }
                    "10.10.10.20" = @{ Cluster = "10.10.10.20"; Credential = $null; SecretName = "my-secret"; VaultName = $null }
                }
            }

            Mock Get-Secret { return $script:pwsh_cred } -ModuleName IBMStorageVirtualize

            $result = InModuleScope IBMStorageVirtualize {
                Copy-IBMSVCertificateViaSCP -SourceCluster "10.10.10.10" -TargetCluster "10.10.10.20" `
                    -CertFile "system_rootcacertificate_slot_3.pem" -TargetCertFile "system_rootcacertificate_slot_3_20250101_120000.pem"
            }

            $result.Success | Should -Be $true
            Assert-MockCalled Get-Secret -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Name -eq "my-secret" -and -not $Vault }
        }
    }

    Context "Credential path - SecretName with VaultName" {
        It "Should call Get-Secret with vault when VaultName is set" {
            InModuleScope IBMStorageVirtualize -Parameters @{ cred = $script:pwsh_cred } {
                $script:sessions = @{
                    "10.10.10.10" = @{ Cluster = "10.10.10.10"; Credential = $null; SecretName = "my-secret"; VaultName = "MyVault" }
                    "10.10.10.20" = @{ Cluster = "10.10.10.20"; Credential = $null; SecretName = "my-secret"; VaultName = "MyVault" }
                }
            }

            Mock Get-Secret { return $script:pwsh_cred } -ModuleName IBMStorageVirtualize

            $result = InModuleScope IBMStorageVirtualize {
                Copy-IBMSVCertificateViaSCP -SourceCluster "10.10.10.10" -TargetCluster "10.10.10.20" `
                    -CertFile "system_rootcacertificate_slot_3.pem" -TargetCertFile "system_rootcacertificate_slot_3_20250101_120000.pem"
            }

            $result.Success | Should -Be $true
            Assert-MockCalled Get-Secret -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Name -eq "my-secret" -and $Vault -eq "MyVault" }
        }
    }

    Context "Credential path - Get-Secret failure" {
        It "Should return Success=false with a clear error message when Get-Secret throws" {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{
                    "10.10.10.10" = @{ Cluster = "10.10.10.10"; Credential = $null; SecretName = "missing-secret"; VaultName = $null }
                    "10.10.10.20" = @{ Cluster = "10.10.10.20"; Credential = $null; SecretName = "missing-secret"; VaultName = $null }
                }
            }

            Mock Get-Secret { throw "Secret not found" } -ModuleName IBMStorageVirtualize

            $result = InModuleScope IBMStorageVirtualize {
                Copy-IBMSVCertificateViaSCP -SourceCluster "10.10.10.10" -TargetCluster "10.10.10.20" `
                    -CertFile "system_rootcacertificate_slot_3.pem" -TargetCertFile "system_rootcacertificate_slot_3_20250101_120000.pem"
            }

            $result.Success | Should -Be $false
            $result.Error   | Should -BeLike "Failed to retrieve secret 'missing-secret'*"
            Assert-MockCalled New-IBMSVSshSession -Times 0 -ModuleName IBMStorageVirtualize
        }
    }

    Context "Credential path - no credential cached, no SecretName" {
        It "Should return Success=false with a clear error message instead of attempting SCP" {
            InModuleScope IBMStorageVirtualize {
                $script:sessions = @{
                    "10.10.10.10" = @{ Cluster = "10.10.10.10"; Credential = $null; SecretName = $null; VaultName = $null }
                    "10.10.10.20" = @{ Cluster = "10.10.10.20"; Credential = $null; SecretName = $null; VaultName = $null }
                }
            }

            $result = InModuleScope IBMStorageVirtualize {
                Copy-IBMSVCertificateViaSCP -SourceCluster "10.10.10.10" -TargetCluster "10.10.10.20" `
                    -CertFile "system_rootcacertificate_slot_3.pem" -TargetCertFile "system_rootcacertificate_slot_3_20250101_120000.pem"
            }

            $result.Success | Should -Be $false
            $result.Error   | Should -BeLike "*No credential available*"

            Assert-MockCalled New-IBMSVSshSession -Times 0 -ModuleName IBMStorageVirtualize
        }
    }
}
