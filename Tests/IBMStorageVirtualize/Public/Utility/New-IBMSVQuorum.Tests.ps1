Describe "New-IBMSVQuorum Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest { return $null } -ModuleName IBMStorageVirtualize
        Mock Get-IBMSVFile { return $null } -ModuleName IBMStorageVirtualize
        Mock Write-IBMSVLog {} -ModuleName IBMStorageVirtualize
    }

    Context "Parameter Validation" {
        It "Should throw when -NoMetadata and -PartnerSystem are both specified" {
            { New-IBMSVQuorum -NoMetadata -PartnerSystem "cluster2" } | Should -Throw "-NoMetadata cannot be specified together with -PartnerSystem."
        }

        It "Should throw when -PartnerIp6 is specified without -PartnerSystem" {
            { New-IBMSVQuorum -PartnerIp6 } | Should -Throw "-PartnerIp6 requires -PartnerSystem to be specified."
        }

        It "Should not call API when -WhatIf is specified" {
            New-IBMSVQuorum -WhatIf

            Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
            Assert-MockCalled Get-IBMSVFile -Times 0 -ModuleName IBMStorageVirtualize
        }
    }

    It "Should create and download quorumapp with no optional parameters" {
        New-IBMSVQuorum

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkquorumapp" -and
                $CmdOpts -eq $null
            }
        Assert-MockCalled Get-IBMSVFile -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Prefix -eq "/dumps" -and
                $Filename -eq "ip_quorum.jar"
            }
    }

    It "Should pass ip_6 to mkquorumapp when -Ip6 is specified" {
        New-IBMSVQuorum -Ip6

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkquorumapp" -and
                $CmdOpts.ip_6 -eq $true
            }
        Assert-MockCalled Get-IBMSVFile -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Prefix -eq "/dumps" -and
                $Filename -eq "ip_quorum.jar"
            }
    }

    It "Should pass nometadata to mkquorumapp when -NoMetadata is specified" {
        New-IBMSVQuorum -NoMetadata

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkquorumapp" -and
                $CmdOpts.nometadata -eq $true
            }
        Assert-MockCalled Get-IBMSVFile -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Prefix -eq "/dumps" -and
                $Filename -eq "ip_quorum.jar"
            }
    }

    It "Should create and download quorumapp with PartnerSystem parameter" {
        New-IBMSVQuorum -PartnerSystem "cluster2"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkquorumapp" -and
                $CmdOpts.partnersystem -eq "cluster2"
            }
        Assert-MockCalled Get-IBMSVFile -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Prefix -eq "/dumps" -and
                $Filename -eq "ip_quorum.jar"
            }
    }

    It "Should pass partnerip6 to mkquorumapp when -PartnerIp6 is specified with -PartnerSystem" {
        New-IBMSVQuorum -PartnerSystem "cluster2" -PartnerIp6

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkquorumapp" -and
                $CmdOpts.partnersystem -eq "cluster2" -and
                $CmdOpts.partnerip6 -eq $true
            }
        Assert-MockCalled Get-IBMSVFile -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Prefix -eq "/dumps" -and
                $Filename -eq "ip_quorum.jar"
            }
    }

    It "Should create and download quorumapp with OutFilePath parameter" {
        New-IBMSVQuorum -OutFilePath "C:\quorum"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkquorumapp" -and
                $CmdOpts -eq $null
            }
        Assert-MockCalled Get-IBMSVFile -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Prefix -eq "/dumps" -and
                $Filename -eq "ip_quorum.jar" -and
                $OutFilePath -eq "C:\quorum"
            }
    }

    It "Should create and download quorumapp with multiple parameters" {
        New-IBMSVQuorum -PartnerSystem "cluster2" -Ip6 -PartnerIp6 -OutFilePath "C:\quorum\myquorum.jar" -Cluster "1.1.1.1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "mkquorumapp" -and
                $CmdOpts.partnersystem -eq "cluster2" -and
                $CmdOpts.ip_6 -eq $true -and
                $CmdOpts.partnerip6 -eq $true -and
                $Cluster -eq "1.1.1.1"
            }
        Assert-MockCalled Get-IBMSVFile -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Prefix -eq "/dumps" -and
                $Filename -eq "ip_quorum.jar" -and
                $OutFilePath -eq "C:\quorum\myquorum.jar" -and
                $Cluster -eq "1.1.1.1"
            }
    }

    It "Should not call Get-IBMSVFile when mkquorumapp fails" {
        Mock Invoke-IBMSVRestRequest {
            return [pscustomobject]@{
                url  = "https://1.1.1.1:7443/rest/v1/mkquorumapp"
                code = 500
                err  = "HTTPError failed"
                out  = @{}
                data = @{}
            }
        } -ModuleName IBMStorageVirtualize

        { New-IBMSVQuorum } | Should -Throw

        Assert-MockCalled Get-IBMSVFile -Times 0 -ModuleName IBMStorageVirtualize
    }
}
