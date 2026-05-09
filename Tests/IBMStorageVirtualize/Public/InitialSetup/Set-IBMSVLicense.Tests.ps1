Describe "Set-IBMSVLicense" {
    BeforeEach {
        $script:callCount = 0
        Mock Invoke-IBMSVRestRequest {
            param($Cmd)

            if ($Cmd -eq "lslicense") {
                return [pscustomobject]@{
                    license_flash='0'; license_remote='0'; license_virtualization='0'
                    license_compression_enclosures='1'; license_compression_capacity='0'
                    license_physical_flash='off'; license_easy_tier='0'; license_cloud_enclosures='0'
                }
            }
            if ($Cmd -eq "lssystem") {
                return [pscustomobject]@{ product_name='IBM FlashSystem 5200' }
            }
            if ($Cmd -eq "lsfeature") {
                return @()
            }
            if ($Cmd -eq 'chlicense') {
                return [pscustomobject]@{ message = 'License updated successfully' }
            }
            if ($Cmd -eq 'activatefeature') {
                return [pscustomobject]@{ message = 'Feature activated successfully' }
            }
            if ($Cmd -eq 'deactivatefeature') {
                return [pscustomobject]@{ message = 'Feature deactivated successfully' }
            }
        } -ModuleName IBMStorageVirtualize
    }
    Context "Licence parameters validation" {
        It "Should throw error when duplicate values are provided" {
            { Set-IBMSVLicense -LicenseKey "0123-4567-89AB-CDEF,0123-4567-89AB-CDEF" } | Should -Throw "Duplicate LicenseKey values found: 0123-4567-89AB-CDEF"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        It "Should not call API when -WhatIf is specified" {
            Set-IBMSVLicense -Flash 1 -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        It "Should update flash" {
            Set-IBMSVLicense -Flash 1

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lslicense' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.flash -eq '1' }
        }

        It "Should update remote" {
            Set-IBMSVLicense -Remote 1

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lslicense' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.remote -eq '1' }
        }

        It "Should update virtualization" {
            Set-IBMSVLicense -Virtualization 1

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lslicense' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.virtualization -eq '1' }
        }

        It "Should update compression" {
            Set-IBMSVLicense -Compression 1

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lslicense' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lssystem' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.compression -eq '1' }
        }

        It "Should update compression for V7000" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lslicense") {
                    return [pscustomobject]@{ license_compression_enclosures='0'; license_compression_capacity='1'}
                }
                if ($Cmd -eq "lssystem") {
                    return [pscustomobject]@{ product_name='IBM Storwize V7000'}
                }
                if ($Cmd -eq 'chlicense') {
                    return [pscustomobject]@{ message = 'License updated successfully' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVLicense -Compression 1

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lslicense' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lssystem' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.compression -eq '1' }
        }

        It "Should update physical flash" {
            Set-IBMSVLicense -PhysicalFlash "on"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lslicense' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.physical_flash -eq 'on' }
        }

        It "Should update easytier" {
            Set-IBMSVLicense -EasyTier 1

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lslicense' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.easytier -eq '1' }
        }

        It "Should update cloud" {
            Set-IBMSVLicense -Cloud 1

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lslicense' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.cloud -eq '1' }
        }
    }

    Context "Feature validation" {
        It "Should not call API when -WhatIf is specified" {
            Set-IBMSVLicense -LicenseKey '0123-4567-89AB-CDEF' -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
        }

        It "Should be idempotennt when updating licensekey" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsfeature") {
                    return [pscustomobject]@{
                        id = '0'
                        license_key = '0123-4567-89AB-CDEF'
                    }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVLicense -LicenseKey '0123-4567-89AB-CDEF'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsfeature' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -in @('activatefeature', 'deactivatefeature') }
        }

        It "Should activate key when new values are provided" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsfeature") {
                    return [pscustomobject]@{
                        id = '0'
                        license_key = '0123-4567-89AB-CDEF'
                    }
                }
                if ($Cmd -eq 'activatefeature') {
                    return [pscustomobject]@{ message = 'Feature activated successfully' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVLicense -LicenseKey '0123-4567-89AB-CDEF,0123-4567-89GH-IJKL'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsfeature' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'activatefeature' -and $CmdOpts.licensekey -eq '0123-4567-89GH-IJKL' }
        }

        It "Should deactivate key when new values are provided" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsfeature") {
                    return @(
                        @{ id = '0'; license_key = '0123-4567-89AB-CDEF' },
                        @{ id = '1'; license_key = '0123-4567-89GH-IJKL' }
                    )
                }
                if ($Cmd -eq 'deactivatefeature') {
                    return [pscustomobject]@{ message = 'Feature deactivated successfully' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVLicense -LicenseKey '0123-4567-89AB-CDEF'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsfeature' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'deactivatefeature' -and $CmdArgs -eq '1' }
        }

        It "Should activate and deactivate keys to match desired state" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lsfeature") {
                    return @(
                        @{ id = '0'; license_key = '0123-4567-89AB-CDEF' }
                        @{ id = '1'; license_key = '0123-4567-89GH-IJKL' }
                    )
                }
                if ($Cmd -eq 'deactivatefeature') {
                    return [pscustomobject]@{ message = 'Feature deactivated successfully' }
                }
                if ($Cmd -eq 'activatefeature') {
                    return [pscustomobject]@{ message = 'Feature activated successfully' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVLicense -LicenseKey '0123-4567-89GH-IJKL,0123-4567-89MN-OPQR'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsfeature' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'deactivatefeature' -and $CmdArgs -eq '0' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'activatefeature' -and $CmdOpts.licensekey -eq '0123-4567-89MN-OPQR' }
        }
    }

    Context "Overall validation" {
        It "Should update all parameters "{
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                $script:callCount++

                if ($Cmd -eq "lslicense") {
                    return [pscustomobject]@{
                        license_flash='0'; license_remote='0'; license_virtualization='0'
                        license_physical_flash='off'; license_easy_tier='0'; license_cloud_enclosures='0'
                        license_compression_enclosures='1'; license_compression_capacity='0'
                    }
                }
                if ($Cmd -eq "lssystem") {
                    return [pscustomobject]@{ product_name='IBM FlashSystem 5200' }
                }
                if ($Cmd -eq "lsfeature") {
                    return @(
                        @{ id = '0'; license_key = '0123-4567-89AB-CDEF' }
                        @{ id = '1'; license_key = '0123-4567-89GH-IJKL' }
                    )
                }
                if ($Cmd -eq 'chlicense') {
                    return [pscustomobject]@{ message = 'License updated successfully' }
                }
                if ($Cmd -eq 'deactivatefeature') {
                    return [pscustomobject]@{ message = 'Feature deactivated successfully' }
                }
                if ($Cmd -eq 'activatefeature') {
                    return [pscustomobject]@{ message = 'Feature activated successfully' }
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVLicense -Flash 1 -Remote 1 -Virtualization 1 -Compression 1 -PhysicalFlash "on" -EasyTier 1 -Cloud 1 -LicenseKey '0123-4567-89GH-IJKL,0123-4567-89MN-OPQR'

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lslicense' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lssystem' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsfeature' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.flash -eq '1' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.remote -eq '1' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.virtualization -eq '1' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.physical_flash -eq 'on' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.easytier -eq '1' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'chlicense' -and $CmdOpts.cloud -eq '1' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'deactivatefeature' -and $CmdArgs -eq '0' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'activatefeature' -and $CmdOpts.licensekey -eq '0123-4567-89MN-OPQR' }
        }

        It "Should be idempotent when updating all parameters"{
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                $script:callCount++

                if ($Cmd -eq "lslicense") {
                    return [pscustomobject]@{
                        license_flash='0'; license_remote='0'; license_virtualization='0'
                        license_physical_flash='off'; license_easy_tier='0'; license_cloud_enclosures='0'
                        license_compression_enclosures='1'; license_compression_capacity='0'
                    }
                }
                if ($Cmd -eq "lssystem") {
                    return [pscustomobject]@{ product_name='IBM FlashSystem 5200' }
                }
                if ($Cmd -eq "lsfeature") {
                    return @(
                        @{ id = '0'; license_key = '0123-4567-89AB-CDEF' }
                        @{ id = '1'; license_key = '0123-4567-89GH-IJKL' }
                    )
                }
            } -ModuleName IBMStorageVirtualize

            Set-IBMSVLicense -Flash 0 -Remote 0 -Virtualization 0 -Compression 0 -PhysicalFlash "off" -EasyTier 0 -Cloud 0 -LicenseKey "0123-4567-89AB-CDEF,0123-4567-89GH-IJKL"

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lslicense' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lssystem' }
            Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
                -ParameterFilter { $Cmd -eq 'lsfeature' }
            Assert-MockCalled Invoke-IBMSVRestRequest -ParameterFilter { $Cmd -eq 'chlicense' } -Times 0 -ModuleName IBMStorageVirtualize
            Assert-MockCalled Invoke-IBMSVRestRequest -ParameterFilter { $Cmd -eq 'activatefeature' } -Times 0 -ModuleName IBMStorageVirtualize
            Assert-MockCalled Invoke-IBMSVRestRequest -ParameterFilter { $Cmd -eq 'deactivatefeature' } -Times 0 -ModuleName IBMStorageVirtualize
        }

        It "Should throw error when REST API call fails" {
            Mock Invoke-IBMSVRestRequest {
                param($Cmd)

                if ($Cmd -eq "lslicense") {
                    return [pscustomobject]@{
                        license_flash='0'; license_remote='0'; license_virtualization='0'
                        license_compression_enclosures='1'; license_compression_capacity='0'
                        license_physical_flash='off'; license_easy_tier='0'; license_cloud_enclosures='0'
                    }
                }
                if ($Cmd -eq 'chlicense') {
                    return [pscustomobject]@{
                        url  = "https://1.1.1.1:7443/rest/v1/chlicense"
                        code = 500
                        err  = "HTTPError failed"
                        out  = @{}
                        data = @{}
                    }
                }
            } -ModuleName IBMStorageVirtualize

            { Set-IBMSVLicense -Flash 1 } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chlicense"
        }
    }
}