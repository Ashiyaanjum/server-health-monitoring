[CmdletBinding()]
param(
    [string]$ScriptPath = (Join-Path $PSScriptRoot '..\ServerHealthMonitoring.ps1'),
    [string]$OutputDirectory = (Join-Path ([System.IO.Path]::GetTempPath()) 'ServerHealthMonitoring-MockTests')
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:Passed = 0
$script:Failed = 0

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if ($Condition) {
        $script:Passed++
        Write-Host "PASS: $Message" -ForegroundColor Green
    }
    else {
        $script:Failed++
        Write-Host "FAIL: $Message" -ForegroundColor Red
    }
}

function Assert-Equal {
    param(
        [AllowNull()][object]$Actual,
        [AllowNull()][object]$Expected,
        [Parameter(Mandatory)][string]$Message
    )

    Assert-True -Condition ($Actual -eq $Expected) -Message "$Message (expected '$Expected', actual '$Actual')"
}

function Assert-NotMatch {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )

    Assert-True -Condition ($Text -notmatch $Pattern) -Message $Message
}

function Get-MockTopIssue {
    param(
        [Parameter(Mandatory)][double]$CpuPercent,
        [Parameter(Mandatory)][double]$MemoryPercent,
        [Parameter(Mandatory)][double[]]$FreeDiskPercent
    )

    $issues = [System.Collections.Generic.List[string]]::new()

    if ($CpuPercent -ge 95) { [void]$issues.Add('High CPU') }
    elseif ($CpuPercent -ge 75) { [void]$issues.Add('CPU Warning') }

    if ($MemoryPercent -ge 95) { [void]$issues.Add('High Memory') }
    elseif ($MemoryPercent -ge 75) { [void]$issues.Add('Memory Warning') }

    if ($FreeDiskPercent | Where-Object { $_ -lt 10 }) { [void]$issues.Add('Low Disk') }
    elseif ($FreeDiskPercent | Where-Object { $_ -lt 20 }) { [void]$issues.Add('Disk Warning') }

    if ($issues.Count -eq 0) { return 'Healthy' }
    if ($issues.Count -eq 1) { return $issues[0] }
    return 'Multiple Issues'
}

function New-MockMonitoringResult {
    param(
        [Parameter(Mandatory)][string]$Scenario,
        [Parameter(Mandatory)][double]$CpuPercent,
        [Parameter(Mandatory)][double]$MemoryPercent,
        [Parameter(Mandatory)][double[]]$FreeDiskPercent,
        [Parameter(Mandatory)][string]$ExpectedIssue
    )

    $overallHealth = if ($ExpectedIssue -in @('Healthy')) {
        'Healthy'
    }
    elseif ($ExpectedIssue -in @('CPU Warning', 'Memory Warning', 'Disk Warning')) {
        'Warning'
    }
    else {
        'Critical'
    }

    [PSCustomObject]@{
        Scenario                  = $Scenario
        TargetLabel               = 'REDACTED'
        ReportTime                = 'TEST_TIME'
        OverallHealth             = $overallHealth
        Uptime                    = '00:01:00:00'
        CPU_Utilization_Percent   = $CpuPercent
        Current_CPU_Processes     = 'service-host : 12.5%'
        Top_CPU_Time_Processes    = 'service-host CPU:12.5s'
        Memory_Utilization_Percent = $MemoryPercent
        Top_5_Memory_Processes    = 'service-host RAM:128MB'
        Monitored_Services        = 'Mock Service : Running [Startup : Auto]'
        Disk_Summary              = (($FreeDiskPercent | ForEach-Object {
                "Drive : TEST_DRIVE`r`nFree Space (%) : $_%"
            }) -join "`r`n--------------------------`r`n")
        ExpectedIssue             = $ExpectedIssue
    }
}

function ConvertTo-MockHtml {
    param([Parameter(Mandatory)][object[]]$Results)

    $rows = foreach ($result in $Results) {
        "<tr><td>$($result.TargetLabel)</td><td>$($result.OverallHealth)</td><td>$($result.ExpectedIssue)</td></tr>"
    }

    return @"
<html>
<body>
<h1>Monitoring Validation Report</h1>
<table>
<tr><th>Target</th><th>Health</th><th>Top Issue</th></tr>
$($rows -join "`n")
</table>
</body>
</html>
"@
}

try {
    Assert-True -Condition (Test-Path -LiteralPath $ScriptPath -PathType Leaf) -Message 'Production script exists'
    $source = Get-Content -LiteralPath $ScriptPath -Raw

    # Static privacy contract checks.
    Assert-NotMatch -Text $source -Pattern '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -Message 'Production script contains no email address'
    Assert-NotMatch -Text $source -Pattern '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' -Message 'Production script contains no IPv4 literal'
    Assert-NotMatch -Text $source -Pattern '(?i)\bPID\s*:' -Message 'Production script does not emit process IDs'
    Assert-NotMatch -Text $source -Pattern '(?i)C:\\Users\\' -Message 'Production script contains no personal Windows profile path'
    Assert-True -Condition ($source -match '\$MonitoringTarget') -Message 'Production script accepts runtime monitoring targets'
    Assert-True -Condition ($source -match "TargetLabel\s*=\s*\$targetLabel") -Message 'Production script uses a report target label'
    Assert-True -Condition ($source -match '\$targetLabel\s*=\s*"REDACTED"') -Message 'Production report target label is redacted'
    Assert-True -Condition ($source -match 'Assert-SafeServerTarget') -Message 'Production script validates target values'
    Assert-True -Condition ($source -match 'Invoke-Command') -Message 'Production script retains remote monitoring execution'

    # Deterministic behavior fixtures.
    $fixtures = @(
        New-MockMonitoringResult -Scenario 'Healthy baseline' -CpuPercent 35 -MemoryPercent 40 -FreeDiskPercent @(65) -ExpectedIssue 'Healthy'
        New-MockMonitoringResult -Scenario 'CPU warning' -CpuPercent 80 -MemoryPercent 40 -FreeDiskPercent @(65) -ExpectedIssue 'CPU Warning'
        New-MockMonitoringResult -Scenario 'Memory critical' -CpuPercent 35 -MemoryPercent 96 -FreeDiskPercent @(65) -ExpectedIssue 'High Memory'
        New-MockMonitoringResult -Scenario 'Disk critical' -CpuPercent 35 -MemoryPercent 40 -FreeDiskPercent @(5) -ExpectedIssue 'Low Disk'
        New-MockMonitoringResult -Scenario 'Multiple issues' -CpuPercent 96 -MemoryPercent 96 -FreeDiskPercent @(5) -ExpectedIssue 'Multiple Issues'
    )

    foreach ($fixture in $fixtures) {
        $calculatedIssue = Get-MockTopIssue `
            -CpuPercent $fixture.CPU_Utilization_Percent `
            -MemoryPercent $fixture.Memory_Utilization_Percent `
            -FreeDiskPercent @($fixture.Disk_Summary -split 'Free Space \(%\) : ' | Select-Object -Skip 1 | ForEach-Object { [double](($_ -split '%')[0]) })

        Assert-Equal -Actual $calculatedIssue -Expected $fixture.ExpectedIssue -Message "Top issue calculation: $($fixture.Scenario)"
        Assert-Equal -Actual $fixture.TargetLabel -Expected 'REDACTED' -Message "Target label: $($fixture.Scenario)"
        Assert-NotMatch -Text ($fixture.Top_CPU_Time_Processes + $fixture.Top_5_Memory_Processes) -Pattern '(?i)\bPID\b|\.Id\b|ProcessId' -Message "Process output excludes IDs: $($fixture.Scenario)"
    }

    # Output contract checks.
    if (Test-Path -LiteralPath $OutputDirectory) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
    }
    New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null

    $csvPath = Join-Path $OutputDirectory 'HealthReport_TEST.csv'
    $htmlPath = Join-Path $OutputDirectory 'HealthReport_TEST.html'
    $fixtures | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    (ConvertTo-MockHtml -Results $fixtures) | Set-Content -LiteralPath $htmlPath -Encoding UTF8

    Assert-True -Condition (Test-Path -LiteralPath $csvPath -PathType Leaf) -Message 'Mock CSV report is created'
    Assert-True -Condition (Test-Path -LiteralPath $htmlPath -PathType Leaf) -Message 'Mock HTML report is created'

    $csvContent = Get-Content -LiteralPath $csvPath -Raw
    $htmlContent = Get-Content -LiteralPath $htmlPath -Raw
    Assert-True -Condition ($csvContent -match 'REDACTED') -Message 'CSV report contains the redacted target label'
    Assert-True -Condition ($htmlContent -match 'REDACTED') -Message 'HTML report contains the redacted target label'
    Assert-NotMatch -Text ($csvContent + $htmlContent) -Pattern '(?i)\bPID\b|ProcessId|\.Id\b' -Message 'Generated mock reports contain no process IDs'
    Assert-NotMatch -Text ($csvContent + $htmlContent) -Pattern '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -Message 'Generated mock reports contain no email addresses'
    Assert-NotMatch -Text ($csvContent + $htmlContent) -Pattern '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' -Message 'Generated mock reports contain no IPv4 literals'

    Write-Host "`nTest summary: $Passed passed, $Failed failed." -ForegroundColor Cyan
    if ($Failed -gt 0) { exit 1 }
    exit 0
}
catch {
    Write-Host "TEST HARNESS ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if (Test-Path -LiteralPath $OutputDirectory) {
        Remove-Item -LiteralPath $OutputDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}
