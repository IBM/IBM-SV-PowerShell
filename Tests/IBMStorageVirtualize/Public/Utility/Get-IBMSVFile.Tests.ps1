Describe "Get-IBMSVFile Tests" {
    BeforeEach {
        Mock Invoke-IBMSVRestRequest { return $null } -ModuleName IBMStorageVirtualize
        Mock Write-IBMSVLog {} -ModuleName IBMStorageVirtualize
    }

    It "Should not call API when -WhatIf is specified" {
        Get-IBMSVFile -Prefix "/dumps" -Filename "ip_quorum.jar" -WhatIf

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 0 -ModuleName IBMStorageVirtualize
    }

    It "Should resolve OutFilePath to PWD when OutFilePath is not specified" {
        $expectedPath = Join-Path -Path $PWD.Path -ChildPath "ip_quorum.jar"

        Get-IBMSVFile -Prefix "/dumps" -Filename "ip_quorum.jar"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "download" -and
                $CmdOpts.prefix -eq "/dumps" -and
                $CmdOpts.filename -eq "ip_quorum.jar" -and
                $OutFile -eq $expectedPath
            }
    }

    It "Should append Filename to OutFilePath when OutFilePath is an existing directory" {
        $tmpFilePath = [System.IO.Path]::GetTempPath()

        Get-IBMSVFile -Prefix "/dumps" -Filename "ip_quorum.jar" -OutFilePath $tmpFilePath

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "download" -and
                $CmdOpts.prefix -eq "/dumps" -and
                $CmdOpts.filename -eq "ip_quorum.jar" -and
                $OutFile -eq (Join-Path $tmpFilePath "ip_quorum.jar")
            }
    }

    It "Should use OutFilePath as full file path when it is not a directory" {
        $tmpFilePath = Join-Path ([System.IO.Path]::GetTempPath()) "myfile.jar"

        Get-IBMSVFile -Prefix "/dumps" -Filename "ip_quorum.jar" -OutFilePath $tmpFilePath

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "download" -and
                $CmdOpts.prefix -eq "/dumps" -and
                $CmdOpts.filename -eq "ip_quorum.jar" -and
                $OutFile -eq $tmpFilePath
            }
    }

    It "Should throw when OutFilePath is a full file path whose parent directory does not exist" {
        $nonExistentParent = Join-Path ([System.IO.Path]::GetTempPath()) "nonexistent_xyz_dir"
        $fullPath = Join-Path $nonExistentParent "myfile.jar"

        { Get-IBMSVFile -Prefix "/dumps" -Filename "ip_quorum.jar" -OutFilePath $fullPath } | Should -Throw "Parent directory '$nonExistentParent' does not exist."
    }

    It "Should pass Cluster to Invoke-IBMSVRestRequest when specified" {
        Get-IBMSVFile -Prefix "/dumps" -Filename "ip_quorum.jar" -Cluster "1.1.1.1"

        Assert-MockCalled Invoke-IBMSVRestRequest -Times 1 -ModuleName IBMStorageVirtualize `
            -ParameterFilter {
                $Cmd -eq "download" -and
                $CmdOpts.prefix -eq "/dumps" -and
                $CmdOpts.filename -eq "ip_quorum.jar" -and
                $Cluster -eq "1.1.1.1"
            }
    }
}
