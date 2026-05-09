Describe "Set-IBMSVEmail" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest {} -ModuleName IBMStorageVirtualize
    }
    It "Should throw error when any SecondaryContact configuration parameters and RemoveSecondaryContact are specified" {
        { Set-IBMSVEmail -SecondaryContactName "pwsh_user0@ibm.com" -SecondaryContactPhone "1111111111" -SecondaryAlternatePhone "2222222222" -RemoveSecondaryContact } | Should -Throw "Parameters -SecondaryContactName, -SecondaryContactPhone, or -SecondaryAlternatePhone are mutually exclusive with -RemoveSecondaryContact."
    }
    It "Should throw error when FromEmail and RemoveFromEmail are both specified" {
        { Set-IBMSVEmail -FromEmail "pwsh_user0@ibm.com" -RemoveFromEmail } | Should -Throw "Parameters -FromEmail and -RemoveFromEmail are mutually exclusive."
    }

    It "Should not call API to update email configuration when -WhatIf is specified" {
        Set-IBMSVEmail -ReplyEmail "pwsh_user0@ibm.com" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should update reply email address" {
        Set-IBMSVEmail -ReplyEmail "pwsh_user0@ibm.com"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $Cmd -eq "chemail" -and $CmdOpts.reply -eq "pwsh_user0@ibm.com" }
    }

    It "Should update FromEmail" {
        Set-IBMSVEmail -FromEmail "pwsh_user0@ibm.com"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $CmdOpts.from -eq "pwsh_user0@ibm.com" }
    }

    It "Should remove FromEmail" {
        Set-IBMSVEmail -RemoveFromEmail

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $CmdOpts.nofrom -eq $true }
    }

    It "Should update primary contact info" {
        Set-IBMSVEmail -PrimaryContactName "pwsh_user1" -PrimaryContactPhone "1111111111" -PrimaryAlternatePhone "2222222222"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $CmdOpts.contact -eq "pwsh_user1" -and
                $CmdOpts.primary -eq "1111111111" -and
                $CmdOpts.alternate -eq "2222222222"
            }
    }

    It "Should update secondary contact info" {
        Set-IBMSVEmail -SecondaryContactName "pwsh_user2" -SecondaryContactPhone "3333333333" -SecondaryAlternatePhone "4444444444"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $CmdOpts.contact2 -eq "pwsh_user2" -and
                $CmdOpts.primary2 -eq "3333333333" -and
                $CmdOpts.alternate2 -eq "4444444444"
            }
    }

    It "Should remove secondary contact" {
        Set-IBMSVEmail -RemoveSecondaryContact

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter { $CmdOpts.nocontact2 -eq $true }
    }

    It "Should update location" {
        Set-IBMSVEmail -Location "Lab"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $CmdOpts.location -eq "Lab"
            }
    }

    It "Should update user info" {
        Set-IBMSVEmail -Organization "IBM" -Address "123/ABC" -City "Pune" -PostalCode "411057" -StateCode "MH" -CountryCode "IN"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $CmdOpts.organization -eq "IBM" -and
                $CmdOpts.address -eq "123/ABC" -and
                $CmdOpts.city -eq "Pune" -and
                $CmdOpts.zip -eq "411057" -and
                $CmdOpts.state -eq "MH" -and
                $CmdOpts.country -eq "IN"
            }
    }

    It "Should throw error when REST API call fails" {
        Mock Invoke-IBMSVRestRequest {
            return [pscustomobject]@{
                url  = "https://1.1.1.1:7443/rest/v1/chemail"
                code = 500
                err  = "HTTPError failed"
                out  = @{}
                data = @{}
            }
        } -ModuleName IBMStorageVirtualize

        { Set-IBMSVEmail -ReplyEmail "pwsh" } | Should -Throw "REST call failed (HTTP 500) to https://1.1.1.1:7443/rest/v1/chemail"
    }

}