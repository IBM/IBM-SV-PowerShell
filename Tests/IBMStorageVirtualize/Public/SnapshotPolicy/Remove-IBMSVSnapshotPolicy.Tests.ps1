Describe "Remove-IBMSVSnapshotPolicy Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq 'lssnapshotpolicy') {
                return [pscustomobject]@{ name = 'pwsh_sp0'; id = '0' }
            }

            if ($Cmd -eq 'rmsnapshotpolicy') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize
    }

    It "Should not call API to remove snapshot policy when -WhatIf is specified" {
        Remove-IBMSVSnapshotPolicy -Name "pwsh_sp0" -Confirm:$false -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not throw error when snapshot policy does not exist" {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)
            if ($Cmd -eq 'lssnapshotpolicy') {
                return $null
            }
        } -ModuleName IBMStorageVirtualize

        { Remove-IBMSVSnapshotPolicy -Name "pwsh_sp0" -Confirm:$false } | Should -Not -Throw

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssnapshotpolicy" -and $CmdArgs -eq "pwsh_sp0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'rmsnapshotpolicy' }
    }

    It "Should remove snapshot policy successfully" {
        Remove-IBMSVSnapshotPolicy -Name "pwsh_sp0" -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssnapshotpolicy" -and $CmdArgs -eq "pwsh_sp0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "rmsnapshotpolicy" -and $CmdArgs -eq "pwsh_sp0" }
    }

    It "Should remove snapshot policy with RemoveFromVolumeGroups option" {
        Remove-IBMSVSnapshotPolicy -Name "pwsh_sp0" -RemoveFromVolumeGroups -Confirm:$false

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "lssnapshotpolicy" -and $CmdArgs -eq "pwsh_sp0" }

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "rmsnapshotpolicy" -and
                $CmdOpts.removefromvolumegroups -eq $true -and
                $CmdArgs -eq "pwsh_sp0"
            }
    }
}
