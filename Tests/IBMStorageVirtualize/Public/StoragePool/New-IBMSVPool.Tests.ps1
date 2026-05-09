Describe "New-IBMSVPool Tests" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            $script:callCount++
            if ($Cmd -eq "lsmdiskgrp") {
                if ($script:callCount -eq 1) { return $null }
                return [pscustomobject]@{ name = 'pwsh_pool0'; id = '1'; status = 'online' }
            }
            if ($Cmd -eq 'mkmdiskgrp') {
                return [pscustomobject]@{ id = '1'; message = 'MDisk Group, id [1], successfully created' }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when -Unit is used without -Size or -Warning" {
        { New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -Unit gb } | Should -Throw "CMMVC5731E Parameter -Unit is invalid without -Size and -Warning."
    }

    It "Should throw error when -Warning and -NoQuota are used together" {
        { New-IBMSVPool -Name "pwsh_pool0" -Warning "80%" -NoQuota } | Should -Throw "Parameters -warning and -NoQuota are mutually exclusive."
    }

    It "Should throw error when -Size and -NoQuota are used together" {
        { New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_parent0" -Size 1024 -NoQuota } | Should -Throw "Parameters -Size and -NoQuota are mutually exclusive."
    }

    It "Should throw error when -Owner and -Safeguarded are used together" {
        { New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_parent0" -Owner "owner0" -Safeguarded } | Should -Throw "Parameters -Owner and -Safeguarded are mutually exclusive."
    }

    It "Should throw error when -OwnershipGroup and -Safeguarded are used together" {
        { New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_parent0" -OwnershipGroup "og0" -Safeguarded } | Should -Throw "Parameters -OwnershipGroup and -Safeguarded are mutually exclusive."
    }

    It "Should throw error when -ParentMdiskGrp is provided with -Ext" {
        { New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_pool" -Ext 1024} | Should -Throw "Parameters -Ext and -ParentMdiskGrp are mutually exclusive."
    }

    It "Should throw error when -ParentMdiskGrp is provided with -EasyTier" {
        { New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_pool" -EasyTier "on" } | Should -Throw "Parameters -EasyTier and -ParentMdiskGrp are mutually exclusive."
    }

    It "Should throw error when -ParentMdiskGrp is provided with -Tier" {
        { New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_pool" -Tier "tier0_flash" } | Should -Throw "Parameters -Tier and -ParentMdiskGrp are mutually exclusive."
    }

    It "Should throw error when -DataReduction is provided with -ParentMdiskGrp" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool'; id = '1'; data_reduction = 'yes' }
            }
        } -ModuleName IBMStorageVirtualize
        { New-IBMSVPool -Name "pwsh_child_pool0" -ParentMdiskGrp "pwsh_pool" -DataReduction 'no' } | Should -Throw "CMMVC9576E Specified ParentMdiskGrp is Data Reduction Pool, to create Data Reduction child pool -DataReduction yes is required."
    }

    It "Should throw error when -Size is provided with -ParentMdiskGrp" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool'; id = '1'; data_reduction = 'yes' }
            }
        } -ModuleName IBMStorageVirtualize
        { New-IBMSVPool -Name "pwsh_child_pool0" -ParentMdiskGrp "pwsh_pool" -DataReduction 'yes' -Size 1024 } | Should -Throw "CMMVC9578E Specified ParentMdiskGrp is Data Reduction Pool, to create Data Reduction child pool -Size is not applicable."
    }

    It "Should throw error when -Encrypt is provided with -ParentMdiskGrp" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool'; id = '1'; data_reduction = 'yes' }
            }
        } -ModuleName IBMStorageVirtualize
        { New-IBMSVPool -Name "pwsh_child_pool0" -ParentMdiskGrp "pwsh_pool" -DataReduction 'yes' -Encrypt "yes"} | Should -Throw "CMMVC9575E Specified ParentMdiskGrp is Data Reduction Pool, to create Data Reduction child pool -Encrypt is not applicable."
    }

    It "Should throw error when -NoQuota is not provided with -ParentMdiskGrp" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool'; id = '1'; data_reduction = 'yes' }
            }
        } -ModuleName IBMStorageVirtualize
        { New-IBMSVPool -Name "pwsh_child_pool0" -ParentMdiskGrp "pwsh_pool" -DataReduction 'yes' } | Should -Throw "CMMVC5707E Specified ParentMdiskGrp is Data Reduction Pool, to create Data Reduction child pool -NoQuota yes is required."
    }

    It "Should throw error when -Size and -NoQuota is not provided with -ParentMdiskGrp" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool'; id = '1'; data_reduction = 'no' }
            }
        } -ModuleName IBMStorageVirtualize
        { New-IBMSVPool -Name "pwsh_child_pool0" -ParentMdiskGrp "pwsh_pool" } | Should -Throw "CMMVC5707E To create Standard Child pool -Size or -NoQuota is required"
    }

    It "Should throw error when ParentMdiskGrp does not exist" {
        Mock Invoke-IBMSVRestRequest { return $null } -ModuleName IBMStorageVirtualize
        { New-IBMSVPool -Name "pwsh_child_pool0" -ParentMdiskGrp "pwsh_pool" } | Should -Throw "ParentMdiskGrp 'pwsh_pool' does not exist."
    }

    It "Should throw error when neither -Ext nor -ParentMdiskGrp is provided" {
        { New-IBMSVPool -Name "pwsh_pool0" } | Should -Throw "One of -Ext or -ParentMdiskGrp parameter is required."
    }

    It "Should throw error when -Size is provided without -ParentMdiskGrp" {
        { New-IBMSVPool -Name "pwsh_pool0" -Size 1024 } | Should -Throw "CMMVC5731E The parameter(s) -Size can only be used when -ParentMdiskGrp is specified."
    }

    It "Should throw error when -NoQuota is provided without -ParentMdiskGrp" {
        { New-IBMSVPool -Name "pwsh_pool0" -NoQuota} | Should -Throw "CMMVC5731E The parameter(s) -NoQuota can only be used when -ParentMdiskGrp is specified."
    }

    It "Should throw error when -Safeguarded is provided without -ParentMdiskGrp" {
        { New-IBMSVPool -Name "pwsh_pool0" -Safeguarded} | Should -Throw "CMMVC5731E The parameter(s) -Safeguarded can only be used when -ParentMdiskGrp is specified."
    }

    It "Should throw error when -Owner is provided without -ParentMdiskGrp" {
        { New-IBMSVPool -Name "pwsh_pool0" -Owner "pwsh_owner"} | Should -Throw "CMMVC5731E The parameter(s) -Owner can only be used when -ParentMdiskGrp is specified."
    }

    It "Should throw error when -OwnershipGroup is provided without -ParentMdiskGrp" {
        { New-IBMSVPool -Name "pwsh_pool0" -OwnershipGroup "pwsh_og"} | Should -Throw "CMMVC5731E The parameter(s) -OwnershipGroup can only be used when -ParentMdiskGrp is specified."
    }

    It "Should throw error when -Size, -Owner, -OwnershipGroup is provided without -ParentMdiskGrp" {
        { New-IBMSVPool -Name "pwsh_pool0" -Size 1024 -Owner "pwsh_owner" -OwnershipGroup "pwsh_og"} | Should -Throw "CMMVC5731E The parameter(s) -Size, -Owner, -OwnershipGroup can only be used when -ParentMdiskGrp is specified."
    }

    It "Should throw error when duplicate values are provided" {
        { New-IBMSVPool -Name "pwsh_pool0" -Ext 1024  -MDisk "pwsh_mdisk0:pwsh_mdisk0" } | Should -Throw "Duplicate MDisk values found: pwsh_mdisk0"
    }

    It "Should not call API to create pool when -WhatIf is specified" {
        New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should be idempotent when pool already exists" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool0'; id = '1'; status = 'online' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdiskgrp" -and $CmdArgs -contains "pwsh_pool0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "mkmdiskgrp" }
    }

    It "Should create a standard pool with -Ext" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 2 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lsmdiskgrp" -and $CmdArgs -contains "pwsh_pool0" }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024
            }
    }

    It "Should create a standard pool with -Tier parameter" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -Tier "tier1_flash"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.tier -eq "tier1_flash"
            }
    }

    It "Should create a standard pool with -EasyTier parameter" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -EasyTier "on"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.easytier -eq "on"
            }
    }

    It "Should create a standard pool with -Encrypt parameter" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -Encrypt "yes"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.encrypt -eq "yes"
            }
    }

    It "Should create a standard pool with -DataReduction parameter" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -DataReduction "yes"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.datareduction -eq "yes"
            }
    }

    It "Should create a standard pool with -Warning parameter" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -Warning "80%"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.warning -eq "80%"
            }
    }

    It "Should create a standard pool with -ProvisioningPolicy parameter" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -ProvisioningPolicy "pp0"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.provisioningpolicy -eq "pp0"
            }
    }

    It "Should create a standard pool with -EtfcmOverAllocationMax parameter" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -EtfcmOverAllocationMax "200%"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.etfcmoverallocationmax -eq "200%"
            }
    }

    It "Should create a standard pool with -VdiskProtectionEnabled parameter" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -VdiskProtectionEnabled "yes"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.vdiskprotectionenabled -eq "yes"
            }
    }

    It "Should create a standard pool with -ReplicationPoolLinkUid parameter" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -ReplicationPoolLinkUid "000000000000000100000123456789C4"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.replicationpoollinkuid -eq "000000000000000100000123456789C4"
            }
    }

    It "Should create a standard pool with -Mdisk parameter" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -Mdisk "mdisk0"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.mdisk -eq "mdisk0"
            }
    }

    It "Should create a standard pool with multiple parameters" {
        $result = New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 -Tier "tier1_flash" -EasyTier "on" -Encrypt "yes" -DataReduction "yes" -Warning "80%" -ProvisioningPolicy "pp0" -VdiskProtectionEnabled "yes"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.ext -eq 1024 -and
                $CmdOpts.tier -eq "tier1_flash" -and
                $CmdOpts.easytier -eq "on" -and
                $CmdOpts.encrypt -eq "yes" -and
                $CmdOpts.datareduction -eq "yes" -and
                $CmdOpts.warning -eq "80%" -and
                $CmdOpts.provisioningpolicy -eq "pp0" -and
                $CmdOpts.vdiskprotectionenabled -eq "yes"
            }
    }

    It "Should create a standard child pool with -Size" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdiskgrp") {
                if ($script:callCount -eq 1) { return [pscustomobject]@{ name = 'pwsh_parent0'; id = '0'; data_reduction = 'no' } }
                if ($script:callCount -eq 2) { return $null }
                return [pscustomobject]@{ name = 'pwsh_pool0'; id = '1'; status = 'online' }
            }
            if ($Cmd -eq 'mkmdiskgrp') {
                return [pscustomobject]@{ id = '1'; message = 'MDisk Group, id [1], successfully created' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_parent0" -Size 1024
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.parentmdiskgrp -eq "pwsh_parent0" -and
                $CmdOpts.size -eq 1024
            }
    }

    It "Should create a standard child pool with -Size and -Safeguarded" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdiskgrp") {
                if ($script:callCount -eq 1) { return [pscustomobject]@{ name = 'pwsh_parent0'; id = '0'; data_reduction = 'no' } }
                if ($script:callCount -eq 2) { return $null }
                return [pscustomobject]@{ name = 'pwsh_pool0'; id = '1'; status = 'online' }
            }
            if ($Cmd -eq 'mkmdiskgrp') {
                return [pscustomobject]@{ id = '1'; message = 'MDisk Group, id [1], successfully created' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_parent0" -Size 1024 -Safeguarded
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.parentmdiskgrp -eq "pwsh_parent0" -and
                $CmdOpts.safeguarded -eq $true -and
                $CmdOpts.size -eq 1024
            }
    }

    It "Should create a standard child pool with -Size and -Owner" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdiskgrp") {
                if ($script:callCount -eq 1) { return [pscustomobject]@{ name = 'pwsh_parent0'; id = '0'; data_reduction = 'no' } }
                if ($script:callCount -eq 2) { return $null }
                return [pscustomobject]@{ name = 'pwsh_pool0'; id = '1'; status = 'online' }
            }
            if ($Cmd -eq 'mkmdiskgrp') {
                return [pscustomobject]@{ id = '1'; message = 'MDisk Group, id [1], successfully created' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_parent0" -Size 1024 -Owner "vvol_child_pool"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.parentmdiskgrp -eq "pwsh_parent0" -and
                $CmdOpts.owner -eq "vvol_child_pool" -and
                $CmdOpts.size -eq 1024
            }
    }

    It "Should create a standard child pool with -NoQuota" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdiskgrp") {
                if ($script:callCount -eq 1) { return [pscustomobject]@{ name = 'pwsh_parent0'; id = '0'; data_reduction = 'no' } }
                if ($script:callCount -eq 2) { return $null }
                return [pscustomobject]@{ name = 'pwsh_pool0'; id = '1'; status = 'online' }
            }
            if ($Cmd -eq 'mkmdiskgrp') {
                return [pscustomobject]@{ id = '1'; message = 'MDisk Group, id [1], successfully created' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_parent0" -NoQuota
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.parentmdiskgrp -eq "pwsh_parent0" -and
                $CmdOpts.noquota -eq $true
            }
    }

    It "Should create a standard child pool with -OwnershipGroup" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdiskgrp") {
                if ($script:callCount -eq 1) { return [pscustomobject]@{ name = 'pwsh_parent0'; id = '0'; data_reduction = 'no' } }
                if ($script:callCount -eq 2) { return $null }
                return [pscustomobject]@{ name = 'pwsh_pool0'; id = '1'; status = 'online' }
            }
            if ($Cmd -eq 'mkmdiskgrp') {
                return [pscustomobject]@{ id = '1'; message = 'MDisk Group, id [1], successfully created' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_parent0" -Size 1024 -OwnershipGroup "pwsh_og0"
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.parentmdiskgrp -eq "pwsh_parent0" -and
                $CmdOpts.size -eq 1024 -and
                $CmdOpts.ownershipgroup -eq "pwsh_og0"
            }
    }

    It "Should create a DR child pool with -DataReduction yes and -NoQuota" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdiskgrp") {
                if ($script:callCount -eq 1) { return [pscustomobject]@{ name = 'pwsh_dr_parent0'; id = '0'; data_reduction = 'yes' } }
                if ($script:callCount -eq 2) { return $null }
                return [pscustomobject]@{ name = 'pwsh_pool0'; id = '1'; status = 'online' }
            }
            if ($Cmd -eq 'mkmdiskgrp') {
                return [pscustomobject]@{ id = '1'; message = 'MDisk Group, id [1], successfully created' }
            }
        } -ModuleName IBMStorageVirtualize

        $result = New-IBMSVPool -Name "pwsh_pool0" -ParentMdiskGrp "pwsh_dr_parent0" -DataReduction "yes" -NoQuota
        $result.name | Should -Be 'pwsh_pool0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkmdiskgrp" -and
                $CmdOpts.name -eq "pwsh_pool0" -and
                $CmdOpts.parentmdiskgrp -eq "pwsh_dr_parent0" -and
                $CmdOpts.datareduction -eq "yes" -and
                $CmdOpts.noquota -eq $true
            }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            return [pscustomobject]@{
                url  = "https://1.1.1.1:7443/rest/v1/mkmdiskgrp"
                code = 500
                err  = "HTTPError failed"
                out  = @{}
                data = @{}
            }
        } -ModuleName IBMStorageVirtualize

        { New-IBMSVPool -Name "pwsh_pool0" -Ext 1024 } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/mkmdiskgrp"
    }
}

