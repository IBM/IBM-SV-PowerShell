[CmdletBinding()]
param(
    [ValidateSet("All","Test","Lint")][string]$Mode = "All",
    [ValidateSet("Table","Csv","Json")][string]$AnalyzerOutput = "Table",
    [string]$TestFile,
    [string]$TestFolder,
    [string]$OutFile
)

$ToolkitRoot = Split-Path -Parent $PSScriptRoot

$ModuleRoot = Join-Path $ToolkitRoot "IBMStorageVirtualize"

$SourcePaths = @(
    (Join-Path $ModuleRoot "Public"),
    (Join-Path $ModuleRoot "Private")
)

$TestRoot = Join-Path $PSScriptRoot "IBMStorageVirtualize"

function Install-RequiredModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name
    )

    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Information "[INSTALL] Installing module '$Name'..." -InformationAction Continue
        Install-Module $Name -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module $Name -ErrorAction Stop
}

if ($Mode -in @("All","Lint")) { Install-RequiredModule -Name PSScriptAnalyzer }
if ($Mode -in @("All","Test")) { Install-RequiredModule -Name Pester }

function Invoke-Lint {
    [CmdletBinding()]
    param(
        [ValidateSet("Table","Csv","Json")][string]$AnalyzerOutput = "Table",
        [string]$OutFile
    )

    Write-Information "`n=== Running ScriptAnalyzer ===" -InformationAction Continue

    $results = foreach ($path in $script:SourcePaths) {
        Write-Information "Analyzing $path" -InformationAction Continue
        Invoke-ScriptAnalyzer -Path $path -Recurse -Severity Error,Warning -ErrorAction Stop
    }

    if (-not $results) {
        Write-Information "`nNo ScriptAnalyzer violations" -InformationAction Continue
        return
    }

    switch ($AnalyzerOutput) {
        "Csv" {
            if (-not $OutFile) { $OutFile = "./ScriptAnalyzerReport.csv" }
            $results | Export-Csv -NoTypeInformation -Path $OutFile
            Write-Information "CSV exported: $OutFile" -InformationAction Continue
        }
        "Json" {
            if (-not $OutFile) { $OutFile = "./ScriptAnalyzerReport.json" }
            $results | ConvertTo-Json -Depth 5 | Set-Content $OutFile -Encoding utf8NoBOM
            Write-Information "JSON exported: $OutFile" -InformationAction Continue
        }
        "Table" {
            $results | Format-Table -AutoSize *
        }
    }
}

function Invoke-UnitTest {
    [CmdletBinding()]
    param(
        [string]$TestFile,
        [string]$TestFolder,
        [ValidateSet("Table","Csv","Json")][string]$OutputFormat = "Table",
        [string]$OutFile
    )

    if ($TestFile) {
        $path = if ([System.IO.Path]::IsPathRooted($TestFile)) {
            $TestFile
        } else {
            Join-Path $script:TestRoot $TestFile
        }

        if (-not (Test-Path $path)) {
            Write-Error "Test file not found: $path"
            exit 1
        }

        $testFiles = Get-Item $path
    }
    elseif ($TestFolder) {
        $folderPath = if ([System.IO.Path]::IsPathRooted($TestFolder)) {
            $TestFolder
        } else {
            Join-Path $script:TestRoot $TestFolder
        }

        if (-not (Test-Path $folderPath)) {
            Write-Error "Test folder not found: $folderPath"
            exit 1
        }

        $testFiles = Get-ChildItem -Path $folderPath -Filter "*.Tests.ps1" -Recurse
    }
    else {
        $testFiles = Get-ChildItem -Path $script:TestRoot -Filter "*.Tests.ps1" -Recurse
    }

    if (-not $testFiles) {
        Write-Error "No test files found"
        exit 1
    }

    Write-Information "`n=== Running Pester Tests ===" -InformationAction Continue
    $results = @()

    foreach ($file in $testFiles) {
        Write-Information "`nRunning Test: $($file.Name)" -InformationAction Continue

        $config = [PesterConfiguration]::Default
        $config.Run.Path     = $file.FullName
        $config.Run.PassThru = $true
        # $config.Output.Verbosity = "Detailed"

        try {
            $result = Invoke-Pester -Configuration $config
        }
        catch {
            $results += [PSCustomObject]@{
                TestFile     = $file.Name
                TotalTests   = 0
                Passed       = 0
                Failed       = 1
                FailedTests  = "ExecutionFailure"
            }
            continue
        }

        $failedTestNames = $result.Tests |
            Where-Object Result -eq 'Failed' |
            Select-Object -ExpandProperty Name

        $results += [PSCustomObject]@{
            TestFile     = $file.Name
            TotalTests   = $result.TotalCount
            Passed       = $result.PassedCount
            Failed       = $result.FailedCount
            FailedTests  = $failedTestNames
        }
    }

    $summary = [PSCustomObject]@{
        TestFile   = "TOTAL"
        TotalTests = [int](($results | Measure-Object TotalTests -Sum).Sum)
        Passed     = [int](($results | Measure-Object Passed -Sum).Sum)
        Failed     = [int](($results | Measure-Object Failed -Sum).Sum)
        FailedTests  = $null
    }

    $finalResults = $results + $summary

    switch ($OutputFormat) {
        "Csv" {
            if (-not $OutFile) { $OutFile = "./UnitTestReport.csv" }

            $csvResults = $finalResults | ForEach-Object {
                [PSCustomObject]@{
                    TestFile    = $_.TestFile
                    TotalTests  = $_.TotalTests
                    Passed      = $_.Passed
                    Failed      = $_.Failed
                    FailedTests = if ($_.FailedTests) { $_.FailedTests -join '; ' } else { $null }
                }
            }

            $csvResults | Export-Csv -NoTypeInformation -Path $OutFile
            Write-Information "`nCSV exported: $OutFile" -InformationAction Continue
        }
        "Json" {
            if (-not $OutFile) { $OutFile = "./UnitTestReport.json" }
            $finalResults | ConvertTo-Json -Depth 5 | Set-Content $OutFile -Encoding utf8NoBOM
            Write-Information "`nJSON exported: $OutFile" -InformationAction Continue
        }
        "Table" {
            $tableResults = $finalResults | ForEach-Object {
                [PSCustomObject]@{
                    TestFile    = $_.TestFile
                    TotalTests  = $_.TotalTests
                    Passed      = $_.Passed
                    Failed      = $_.Failed
                    FailedTests = if ($_.FailedTests) { $_.FailedTests -join ', ' } else { '' }
                }
            }

            $tableResults | Format-Table -AutoSize *
        }
    }

    if ($summary.Failed -gt 0) {
        Write-Information "`nUnit tests failed" -InformationAction Continue
        exit 1
    }

    Write-Information "`nAll unit tests passed" -InformationAction Continue
}

switch ($Mode) {
    "Lint" { Invoke-Lint -AnalyzerOutput $AnalyzerOutput -OutFile $OutFile }

    "Test" {
        Invoke-UnitTest -TestFile $TestFile -TestFolder $TestFolder -OutputFormat $AnalyzerOutput -OutFile $OutFile
    }

    "All"  {
        Invoke-Lint -AnalyzerOutput $AnalyzerOutput -OutFile $OutFile
        Invoke-UnitTest -TestFile $TestFile -TestFolder $TestFolder -OutputFormat $AnalyzerOutput -OutFile $OutFile
    }
}
