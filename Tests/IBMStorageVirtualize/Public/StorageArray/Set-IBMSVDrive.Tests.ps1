Describe "Set-IBMSVDrive Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {
            param($Cmd, $CmdArgs)
            if ($Cmd -eq 'lsdriveprogress') {
                return @{ id = $CmdArgs; task = 'format'; progress = ''; estimated_completion_timed = '' }
            }
        } -ModuleName IBMStorageVirtualize
        Mock Write-IBMSVLog {} -ModuleName IBMStorageVirtualize
    }

    It "Should throw error when neither -State nor -Task is specified" {
        { Set-IBMSVDrive -Id 0 } | Should -Throw "Either -State or -Task parameter must be specified."
    }

    It "Should throw error when -State and -Task are both specified" {
        { Set-IBMSVDrive -Id 0 -State 'candidate' -Task 'format' } | Should -Throw "Parameters -State and -Task are mutually exclusive."
    }

    It "Should not call any API when -WhatIf is specified with -State" {
        Set-IBMSVDrive -Id 0 -State 'candidate' -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should not call any API when -WhatIf is specified with -Task" {
        Set-IBMSVDrive -Id 0 -Task 'format' -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should accept pipeline input and update drive state" {
        Mock Get-IBMSVDrive {
            return @(
                [pscustomobject]@{ id = '0'; use = 'unused' }
                [pscustomobject]@{ id = '1'; use = 'unused' }
                [pscustomobject]@{ id = '2'; use = 'unused' }
            )
        }

        Get-IBMSVDrive | Set-IBMSVDrive -State 'candidate'

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chdrive' -and $CmdArgs -eq 0 }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chdrive' -and $CmdArgs -eq 1 }
        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq 'chdrive' -and $CmdArgs -eq 2 }
    }

    Context "State Operations" {
        It "Should update drive with the correct state" {
            Set-IBMSVDrive -Id 0 -State 'candidate'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chdrive' -and $CmdOpts.use -eq 'candidate' -and $CmdArgs -eq 0 }
        }

        It "Should throw error when chdrive REST call fails for -State" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'chdrive') {
                    return [pscustomobject]@{
                        url  = 'https://1.1.1.1:7443/rest/v1/chdrive/0'
                        code = 500
                        err  = 'HTTPError failed'
                        out  = @{}
                        data = @{}
                    }
                }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVDrive -Id 0 -State 'candidate' } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chdrive/0"
        }
    }

    Context "Task Operations" {
        It "Should trigger drive dump" {
            Set-IBMSVDrive -Id 0 -Task 'triggerdump'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'triggerdrivedump' -and $CmdArgs -eq 0 }
        }

        It "Should format drive when no task is in progress" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lsdriveprogress') {
                    return @{ id = '0'; task = ''; progress = ''; estimated_completion_timed = '' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVDrive -Id 0 -Task 'format'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chdrive' -and $CmdOpts.task -eq 'format' -and $CmdArgs -eq 0 }
        }

        It "Should be idempotent when same task is already in progress" {
            Set-IBMSVDrive -Id 0 -Task 'format'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chdrive' }
        }

        It "Should throw error when a different task is already in progress" {
            { Set-IBMSVDrive -Id 0 -Task 'certify' } | Should -Throw "CMMVC6625E Task 'format' is already in progress on drive ID 0. Cannot start task 'certify'."
        }

        It "Should throw error when drive does not exist (lsdriveprogress returns null)" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)
                if ($Cmd -eq 'lsdriveprogress') { return $null }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVDrive -Id 99 -Task 'format' } | Should -Throw "Drive ID '99' does not exist."
        }
    }
}
