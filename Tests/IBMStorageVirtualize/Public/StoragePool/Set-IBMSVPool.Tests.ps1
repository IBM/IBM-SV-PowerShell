Describe "Set-IBMSVPool Tests" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdiskgrp") {
                if ($script:callCount -eq 1) {
                    return [pscustomobject]@{
                        name = 'pwsh_pool0'; id = '0'; easy_tier = 'auto'; owner_name = '';
                        provisioning_policy_name = 'pwsh_pp0'; vdisk_protection_enabled = 'no';
                        replication_pool_link_uid = '000000000000000000000123456789A1'; warning = '0'; capacity = '1073741824';
                        used_capacity = '0'; easy_tier_fcm_over_allocation_max = '100%'
                    }
                }
                return $null
            }
            if ($Cmd -eq 'chmdiskgrp') {
                return [pscustomobject]@{ message = 'Pool updated successfully' }
            }
            if ($Cmd -eq 'lspartnership') {
                return [pscustomobject]@{
                    id = '00000204AEA0632C'; name = 'pwsh_system'; location = 'remote';
                    partnership = 'fully_configured'; partnership_index = '1'
                }
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when -Unit is used without -Size or -Warning" {
        { Set-IBMSVPool -Name "pwsh_pool0" -Unit gb } | Should -Throw "CMMVC5731E Parameter -Unit is invalid without -Size and -Warning."
    }

    It "Should throw error when -OwnershipGroup and -NoOwnershipGroup are used together" {
        { Set-IBMSVPool -Name "pwsh_pool0" -OwnershipGroup "og0" -NoOwnershipGroup } | Should -Throw "Parameters -OwnershipGroup and -NoOwnershipGroup are mutually exclusive."
    }

    It "Should throw error when -ProvisioningPolicy and -NoProvisioningPolicy are used together" {
        { Set-IBMSVPool -Name "pwsh_pool0" -ProvisioningPolicy "pp0" -NoProvisioningPolicy } | Should -Throw "Parameters -ProvisioningPolicy and -NoProvisioningPolicy are mutually exclusive."
    }

    It "Should throw error when -MovePoolLink is used without -ReplicationPoolLinkUid" {
        { Set-IBMSVPool -Name "pwsh_pool0" -MovePoolLink } | Should -Throw "Parameter -MovePoolLink is invalid without -ReplicationPoolLinkUid."
    }

    It "Should throw error when -ReplaceExistingLink is used without -ReplicationPoolLinkUid or -ResetReplicationPoolLinkUid" {
        { Set-IBMSVPool -Name "pwsh_pool0" -ReplaceExistingLink } | Should -Throw "Parameter -ReplaceExistingLink is invalid without -ReplicationPoolLinkUid or -ResetReplicationPoolLinkUid."
    }

    It "Should throw error when -ReplicationPoolLinkUid and -ResetReplicationPoolLinkUid are used together" {
        { Set-IBMSVPool -Name "pwsh_pool0" -ReplicationPoolLinkUid "UID1" -ResetReplicationPoolLinkUid } | Should -Throw "Parameters -ReplicationPoolLinkUid, -ResetReplicationPoolLinkUid are mutually exclusive."
    }

    It "Should throw error when -ReplicationPoolLinkUid and -ReplicationPartnerClusterid are used together" {
        { Set-IBMSVPool -Name "pwsh_pool0" -ReplicationPoolLinkUid "UID1" -ReplicationPartnerClusterid "cluster1" } | Should -Throw "Parameters -ReplicationPoolLinkUid, -ReplicationPartnerClusterid are mutually exclusive."
    }

    It "Should throw error when pool does not exist" {
        Mock Invoke-IBMSVRestRequest { return $null } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPool -Name 'pwsh_pool0' } | Should -Throw "Pool 'pwsh_pool0' does not exist."
    }

    It "Should throw error when both pool and new name does not exist" {
        Mock Invoke-IBMSVRestRequest { return $null } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPool -Name 'pwsh_pool0' -NewName 'pwsh_pool1' } | Should -Throw "Pool 'pwsh_pool0' does not exist."
    }

    It "Should throw error when both -Name pool and -NewName pool exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdiskgrp") {
                if ($script:callCount -eq 1) { return [pscustomobject]@{ name = 'pwsh_pool0'; id = '0' } }
                return [pscustomobject]@{ name = 'pwsh_pool1'; id = '1' }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPool -Name 'pwsh_pool0' -NewName 'pwsh_pool1' } | Should -Throw "Both 'pwsh_pool0' and 'pwsh_pool1' exist. Cannot rename, cannot proceed with other updates."
    }

    It "Should not throw error when same pool name is used for rename" {
        { Set-IBMSVPool -Name 'pwsh_pool0' -NewName 'pwsh_pool0' } | Should -Not -Throw
    }

    It "Should not call API to update pool when -WhatIf is specified" {
        Set-IBMSVPool -Name 'pwsh_pool0' -EasyTier 'on' -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
             -ParameterFilter { $Cmd -eq 'chmdiskgrp' }
    }

    It "Should not throw error when -Name pool does not exist but -NewName pool exists and proceed to update other params on -NewName pool" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdiskgrp") {
                if ($script:callCount -eq 1) { return $null }
                return [pscustomobject]@{ name = 'pwsh_pool1'; id = '1'; easy_tier = 'auto' }
            }
            if ($Cmd -eq 'chmdiskgrp') {
                return [pscustomobject]@{ message = 'Pool updated successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPool -Name 'pwsh_pool0' -NewName 'pwsh_pool1' -EasyTier 'on'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.easytier -eq 'on' -and
                $CmdArgs -eq 'pwsh_pool1'
            }
    }

    It "Should update pool EasyTier" {
        Set-IBMSVPool -Name 'pwsh_pool0' -EasyTier 'on'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.easytier -eq 'on' -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should add ownership group" {
        Set-IBMSVPool -Name 'pwsh_pool0' -OwnershipGroup 'pwsh_og0'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.ownershipgroup -eq 'pwsh_og0' -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should remove ownership group with -NoOwnershipGroup" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool0'; owner_name = 'pwsh_og0' }
            }
            if ($Cmd -eq 'chmdiskgrp') {
                return [pscustomobject]@{ message = 'Pool updated successfully' }
            }
        } -ModuleName IBMStorageVirtualize

        Set-IBMSVPool -Name 'pwsh_pool0' -NoOwnershipGroup

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.noownershipgroup -eq $true -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should add provisioning policy" {
        Set-IBMSVPool -Name 'pwsh_pool0' -ProvisioningPolicy 'pwsh_pp1'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.provisioningpolicy -eq 'pwsh_pp1' -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should remove provisioning policy with -NoProvisioningPolicy" {
        Set-IBMSVPool -Name 'pwsh_pool0' -NoProvisioningPolicy

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.noprovisioningpolicy -eq $true -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should update VdiskProtectionEnabled" {
        Set-IBMSVPool -Name 'pwsh_pool0' -VdiskProtectionEnabled 'yes'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.vdiskprotectionenabled -eq 'yes' -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should update Warning (percentage)" {
        Set-IBMSVPool -Name 'pwsh_pool0' -Warning '80%'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.warning -eq '80%' -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should update pool Size" {
        Set-IBMSVPool -Name 'pwsh_pool0' -Size 2 -Unit 'gb'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.size -eq 2 -and
                $CmdOpts.unit -eq 'gb' -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should throw error when specified size is less than used capacity" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool0'; capacity = '10737418240'; used_capacity = '7516192768' }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPool -Name 'pwsh_pool0' -Size 5 -Unit 'gb' } | Should -Throw "CMMVC8427E Requested size is smaller than used capacity. Shrink denied."
    }

    It "Should update EtfcmOverAllocationMax" {
        Set-IBMSVPool -Name 'pwsh_pool0' -EtfcmOverAllocationMax '200%'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.etfcmoverallocationmax -eq '200%' -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should disable EtfcmOverAllocationMax by setting it to off" {
        Set-IBMSVPool -Name 'pwsh_pool0' -EtfcmOverAllocationMax 'off'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.etfcmoverallocationmax -eq 'off' -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should update ReplicationPoolLinkUid" {
        Set-IBMSVPool -Name 'pwsh_pool0' -ReplicationPoolLinkUid '000000000000000000000123456789A2'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.replicationpoollinkuid -eq '000000000000000000000123456789A2' -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should update ReplicationPoolLinkUid with MovePoolLink" {
        Set-IBMSVPool -Name 'pwsh_pool0' -ReplicationPoolLinkUid '000000000000000000000123456789A2' -MovePoolLink

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.replicationpoollinkuid -eq '000000000000000000000123456789A2' -and
                $CmdOpts.movepoollink -eq $true -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should reset ReplicationPoolLinkUid with -ReplaceExistingLink" {
        Set-IBMSVPool -Name 'pwsh_pool0' -ResetReplicationPoolLinkUid -ReplaceExistingLink

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.resetreplicationpoollinkuid -eq $true -and
                $CmdOpts.replaceexistinglink -eq $true -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should update pool with -ReplicationPartnerClusterid" {
        Set-IBMSVPool -Name 'pwsh_pool0' -ReplicationPartnerClusterid 'pwsh_system'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.replicationpoollinkedsystemsmask -eq '10' -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should throw error when -ReplicationPartnerClusterid specified but partnership does not exist." {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            $script:callCount++

            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{ name = 'pwsh_pool0' }
            }
            if ($Cmd -eq 'lspartnership') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPool -Name 'pwsh_pool0' -ReplicationPartnerClusterid 'pwsh_system' } | Should -Throw "Partnership does not exist for the given cluster 'pwsh_system'."
    }

    It "Should update pool with multiple parameters" {
        Set-IBMSVPool -Name 'pwsh_pool0' -NewName 'pwsh_pool1' -EasyTier 'on' -ProvisioningPolicy 'pwsh_pp1' -VdiskProtectionEnabled 'yes' -Warning '80%' -EtfcmOverAllocationMax '200%' -ReplicationPoolLinkUid '000000000000000000000123456789A2' -MovePoolLink

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq 'chmdiskgrp' -and
                $CmdOpts.name -eq 'pwsh_pool1' -and
                $CmdOpts.easytier -eq 'on' -and
                $CmdOpts.provisioningpolicy -eq 'pwsh_pp1' -and
                $CmdOpts.vdiskprotectionenabled -eq 'yes' -and
                $CmdOpts.etfcmoverallocationmax -eq '200%' -and
                $CmdOpts.warning -eq '80%' -and
                $CmdOpts.replicationpoollinkuid -eq '000000000000000000000123456789A2' -and
                $CmdOpts.movepoollink -eq $true -and
                $CmdArgs -eq 'pwsh_pool0'
            }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lsmdiskgrp") {
                return [pscustomobject]@{
                    name = 'pwsh_pool0'; id = '0'; easy_tier = 'auto'; owner_name = '';
                    provisioning_policy_name = ''; vdisk_protection_enabled = 'no';
                    replication_pool_link_uid = ''; warning = '0'; capacity = '1073741824';
                    used_capacity = '0'; easy_tier_fcm_over_allocation_max = '100%'
                }
            }
            if ($Cmd -eq 'chmdiskgrp') {
                return [pscustomobject]@{
                    url  = "https://1.1.1.1:7443/rest/v1/chmdiskgrp/pwsh_pool"
                    code = 500
                    err  = "HTTPError failed"
                    out  = @{}
                    data = @{}
                }
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVPool -Name 'pwsh_pool0' -EasyTier 'on' } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chmdiskgrp/pwsh_pool"
    }
}
