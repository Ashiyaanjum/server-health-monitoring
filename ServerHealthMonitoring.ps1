
#________________# Version : 1.1 - Hardened
# Security: configure approved targets, SMTP TLS, and runtime credentials before use.
# Last Updated : July 2026____________________________________________________________________________________________________________________________
#July 2026
#Title : Standalone Advanced Server Health & Service Monitoring (PerfMon Enhanced)
# Description:
# Performs advanced monitoring checks on Windows servers using Performance
# Monitor counters. Reports CPU, memory, disk utilization, top resource-
# consuming processes, monitored services, system uptime, and lists the
# top-level folders available on each local drive for quick investigation.

#Author: [REDACTED]
#
#Recommendation : Initially test this script on a lower environment, then run it on Prod.
#____________________________________________________________________________________________________________________________________________

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$MonitoringTarget
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

function ConvertTo-HtmlSafe {
    param([AllowNull()][object]$Value)
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Assert-SafeServerTarget {
    param(
        [Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)][string[]]$AllowedServers
    )

    if ($ComputerName -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$' -or $ComputerName -match '\.\.') {
        throw "Invalid server target format."
    }

    if ($ComputerName.Trim().ToLowerInvariant() -eq 'localhost') {
        if ('localhost' -notin ($AllowedServers | ForEach-Object { $_.ToLowerInvariant() })) {
            throw "localhost is not an approved monitoring target."
        }
        return
    }

    $normalized = $ComputerName.ToLowerInvariant()
    $allowed = $AllowedServers | ForEach-Object { $_.Trim().ToLowerInvariant() }
    if ($normalized -notin $allowed) {
        throw "Server target is not in the approved allowlist."
    }
}

function New-ServerHealthDashboard {

    param(
        [string]$CsvPath,
        [array]$DashboardResults
    )

$Servers = Import-Csv $CsvPath

# Summary uses ALL monitored servers
$TotalServers = $DashboardResults.Count

$HealthyServers = ($DashboardResults | Where-Object {
    $_.OverallHealth -eq "Healthy"
}).Count

$WarningServers = ($DashboardResults | Where-Object {
    $_.OverallHealth -eq "Warning"
}).Count

$CriticalServers = ($DashboardResults | Where-Object {
    $_.OverallHealth -eq "Critical"
}).Count

# Table still shows only affected servers
$AffectedServers = $Servers.Count


    $rows = ""

    foreach ($server in $Servers)
    {
        #-------------------------------------------------------
        # Health Badge
        #-------------------------------------------------------
        switch ($server.OverallHealth)
        {
            "Healthy"
            {
                $Health = "<span style='background:#d4edda;color:#155724;padding:6px 14px;border-radius:20px;font-weight:bold;'>Healthy</span>"
                $CellColor = "#d4edda"
            }

            "Warning"
            {
                $Health = "<span style='background:#fff3cd;color:#856404;padding:6px 14px;border-radius:20px;font-weight:bold;'>Warning</span>"
                $CellColor = "#fff3cd"
            }

            "Critical"
            {
                $Health = "<span style='background:#f8d7da;color:#721c24;padding:6px 14px;border-radius:20px;font-weight:bold;'>Critical</span>"
                $CellColor = "#f8d7da"
            }

            default
            {
                $Health = $server.OverallHealth
                $CellColor = "#ffffff"
            }
        }

        #-------------------------------------------------------
        # CPU
        #-------------------------------------------------------
        $CpuValue = [double]$server.CPU_Utilization_Percent

if($CpuValue -ge 90){
    $CpuColor="#f8d7da"
}
elseif($CpuValue -ge 75){
    $CpuColor="#fff3cd"
}
else{
    $CpuColor="#d4edda"
}

$CPUStatus = "Healthy"

if($CpuValue -ge 90)
{
    $CPUStatus = "<span style='color:#dc3545;font-weight:bold;'>Critical</span>"
}
elseif($CpuValue -ge 75)
{
    $CPUStatus = "<span style='color:#f39c12;font-weight:bold;'>Warning</span>"
}
else
{
    $CPUStatus = "<span style='color:#28a745;font-weight:bold;'>Healthy</span>"
}

$CPU = @"
<div style='width:140px;'>

<div style='text-align:center;font-weight:bold;'>
$CpuValue%
</div>

<div style='width:100%;
background:#e9ecef;
height:14px;
border-radius:10px;'>

<div style='width:$CpuValue%;
background:$CpuColor;
height:14px;
border-radius:10px;'>

</div>

</div>

<div style='text-align:center;
margin-top:4px;
font-size:11px;'>

$CPUStatus

</div>

</div>
"@



        #-------------------------------------------------------
        # Memory
        #-------------------------------------------------------
        $MemValue = [double]$server.Memory_Utilization_Percent

if($MemValue -ge 90){
    $MemColor="#f8d7da"
}
elseif($MemValue -ge 75){
    $MemColor="#fff3cd"
}
else{
    $MemColor="#d4edda"
}
$MemoryStatus = "Healthy"

if($MemValue -ge 90)
{
    $MemoryStatus = "<span style='color:#dc3545;font-weight:bold;'>Critical</span>"
}
elseif($MemValue -ge 75)
{
    $MemoryStatus = "<span style='color:#f39c12;font-weight:bold;'>Warning</span>"
}
else
{
    $MemoryStatus = "<span style='color:#28a745;font-weight:bold;'>Healthy</span>"
}

$Memory = @"
<div style='width:140px;'>

<div style='text-align:center;font-weight:bold;'>
$MemValue%
</div>

<div style='width:100%;
background:#e9ecef;
height:14px;
border-radius:10px;'>

<div style='width:$MemValue%;
background:$MemColor;
height:14px;
border-radius:10px;'>

</div>

</div>

<div style='text-align:center;
margin-top:4px;
font-size:11px;'>

$MemoryStatus

</div>

</div>
"@



        #-------------------------------------------------------
        # Disk Formatting
        #-------------------------------------------------------

        $DiskHTML = ""

        $drives = ($server.Disk_Summary -split "--------------------------")

        foreach($drive in $drives)
        {
            if([string]::IsNullOrWhiteSpace($drive))
            {
                continue
            }

            $DriveLetter = ([regex]::Match($drive,"Drive\s*:\s*(.+)")).Groups[1].Value.Trim()
            $FreePercent = [double](([regex]::Match($drive,"Free Space \(%\)\s*:\s*([0-9\.]+)")).Groups[1].Value)
if($FreePercent -lt 10)
{
    $Color = "#dc3545"       # Critical
}
elseif($FreePercent -lt 20)
{
    $Color = "#f39c12"       # Warning
}
else
{
    $Color = "#28a745"       # Healthy
}

$DiskHTML += @"
<div style='
display:inline-block;
margin:4px;
padding:6px 12px;
background:$Color;
color:white;
border-radius:16px;
font-size:11px;
font-weight:bold;
min-width:95px;
text-align:center;'>

$DriveLetter

<br>

$FreePercent% Free

</div>
"@    }
#-------------------------------------------------------
# Top Issue
#-------------------------------------------------------

#-------------------------------------------------------
# Top Issue
#-------------------------------------------------------

$Issues = @()

$DiskCritical = $false
$DiskWarning  = $false

foreach($drive in $drives)
{
    if([string]::IsNullOrWhiteSpace($drive))
    {
        continue
    }

    if($drive -match "Free Space \(%\)\s*:\s*([0-9\.]+)")
    {
        $Free = [double]$Matches[1]

        if($Free -lt 10)
        {
            $DiskCritical = $true
        }
        elseif($Free -lt 20)
        {
            $DiskWarning = $true
        }
    }
}

if($CpuValue -ge 90)
{
    $Issues += "High CPU"
}
elseif($CpuValue -ge 75)
{
    $Issues += "CPU Warning"
}

if($MemValue -ge 90)
{
    $Issues += "High Memory"
}
elseif($MemValue -ge 75)
{
    $Issues += "Memory Warning"
}

if($DiskCritical)
{
    $Issues += "Low Disk"
}
elseif($DiskWarning)
{
    $Issues += "Disk Warning"
}

if($Issues.Count -eq 0)
{
    $TopIssue = "Healthy"
}
elseif($Issues.Count -eq 1)
{
    $TopIssue = $Issues[0]
}
else
{
    $TopIssue = "Multiple Issues"
}

switch ($TopIssue)
{
    "Healthy"         { $TopIssueColor = "#28a745" }
    "CPU Warning"     { $TopIssueColor = "#f39c12" }
    "Memory Warning"  { $TopIssueColor = "#f39c12" }
    "Disk Warning"    { $TopIssueColor = "#f39c12" }
    "High CPU"        { $TopIssueColor = "#dc3545" }
    "High Memory"     { $TopIssueColor = "#dc3545" }
    "Low Disk"        { $TopIssueColor = "#dc3545" }
    "Multiple Issues" { $TopIssueColor = "#dc3545" }
    default           { $TopIssueColor = "#0F6CBD" }
}


        #-------------------------------------------------------
        # Row
        #-------------------------------------------------------

       $rows += @"
<tr>

<td style='font-weight:600;
color:#1f2937;
padding:12px;'>

$(ConvertTo-HtmlSafe $server.TargetLabel)

</td>

<td align='center'
style='padding:12px;'>

$Health

</td>

<td align='center'
style='padding:12px;'>

$CPU

</td>

<td align='center'
style='padding:12px;'>

$Memory

</td>

<td style='padding:12px;'>

$DiskHTML

</td>

<td
style='
padding:12px;
font-weight:bold;
text-align:center;
color:#0F6CBD;'>

$TopIssue

</td>

<td
style='
padding:12px;
text-align:center;
font-weight:bold;
color:#555;'>

$(ConvertTo-HtmlSafe $server.Uptime)

</td>

<td
style='
padding:12px;
text-align:center;
white-space:nowrap;'>

$(ConvertTo-HtmlSafe $server.ReportTime)

</td>
</tr>

"@
    }

    $html = @"
<html>

<head>

<style>

body{

font-family:Segoe UI,Arial;
font-size:12px;
background:white;
}

h2{

color:#0F6CBD;
text-align:center;

}

table{

border-collapse:collapse;
width:100%;

}

th{

background:#0F6CBD;
color:white;
padding:10px;
border:1px solid #dcdcdc;

}

td{

padding:8px;
border:1px solid #dcdcdc;
vertical-align:top;

}

tr:nth-child(even){

background:#f8f8f8;

}

</style>

</head>

<body>

<div style="background:linear-gradient(90deg,#0F6CBD,#005A9E);
padding:20px;
border-radius:10px;
color:white;
text-align:center;
margin-bottom:20px;">

<h1 style="margin:0;">
Enterprise Server Health Monitoring Report
</h1>

<div style="margin-top:10px;font-size:13px;">

<b>Report Date:</b> $(Get-Date -Format "dd-MMM-yyyy hh:mm tt")

&nbsp;&nbsp;&nbsp;&nbsp;

<b>Generated By:</b> Enterprise Windows Server Monitoring Framework

</div>

</div>

<table width="100%" cellpadding="10" cellspacing="10" style="margin-bottom:25px;">
<tr>

<td width="20%" valign="top">

<div style="
background:#0F6CBD;
color:white;
padding:18px;
border-radius:10px;
text-align:center;
min-height:120px;">

<div style="
font-size:12px;
font-weight:bold;
letter-spacing:1px;
text-transform:uppercase;">
Total Servers
</div>

<div style="
font-size:34px;
font-weight:bold;
margin-top:8px;">

$TotalServers

</div>

<div style="
font-size:14px;
font-weight:bold;
margin-top:8px;">

Total Servers

</div>

<div style="
font-size:11px;
margin-top:6px;">

Servers Monitored

</div>

</div>

</td>

<td width="20%" valign="top">

<div style="
background:#28a745;
color:white;
padding:18px;
border-radius:10px;
text-align:center;
min-height:120px;">

<div style="
font-size:12px;
font-weight:bold;
letter-spacing:1px;
text-transform:uppercase;">
HEALTHY
</div>

<div style="
font-size:34px;
font-weight:bold;
margin-top:8px;">

$HealthyServers

</div>

<div style="
font-size:14px;
font-weight:bold;
margin-top:8px;">

Healthy

</div>

<div style="
font-size:11px;
margin-top:6px;">

No Action Required

</div>

</div>

</td>

<td width="20%" valign="top">

<div style="
background:#f39c12;
color:white;
padding:18px;
border-radius:10px;
text-align:center;
min-height:120px;">

<div style="
font-size:12px;
font-weight:bold;
letter-spacing:1px;
text-transform:uppercase;">
Warning
</div>


<div style="
font-size:34px;
font-weight:bold;
margin-top:8px;">

$WarningServers

</div>

<div style="
font-size:14px;
font-weight:bold;
margin-top:8px;">

Warning

</div>

<div style="
font-size:11px;
margin-top:6px;">

Requires Attention

</div>

</div>

</td>

<td width="20%" valign="top">

<div style="
background:#dc3545;
color:white;
padding:18px;
border-radius:10px;
text-align:center;
min-height:120px;">

<div style="
font-size:12px;
font-weight:bold;
letter-spacing:1px;
text-transform:uppercase;">
Critical Server
</div>

<div style="
font-size:34px;
font-weight:bold;
margin-top:8px;">

$CriticalServers

</div>

<div style="
font-size:14px;
font-weight:bold;
margin-top:8px;">

Critical

</div>

<div style="
font-size:11px;
margin-top:6px;">

Immediate Action

</div>

</div>

</td>

<td width="20%" valign="top">

<div style="
background:#6f42c1;
color:white;
padding:18px;
border-radius:10px;
text-align:center;
min-height:120px;">

<div style="
font-size:12px;
font-weight:bold;
letter-spacing:1px;
text-transform:uppercase;">
Affected
</div>

<div style="
font-size:34px;
font-weight:bold;
margin-top:8px;">

$AffectedServers

</div>

<div style="
font-size:14px;
font-weight:bold;
margin-top:8px;">

Affected

</div>

<div style="
font-size:11px;
margin-top:6px;">

Servers Reported

</div>

</div>

</td>

</tr>

</table>

<table width="100%" cellpadding="0" cellspacing="0"
style="
margin-bottom:20px;
border:1px solid #d9e2ec;
border-radius:8px;
background:#f8fbff;">

<tr>

<td style="padding:18px;">

<div style="
font-size:18px;
font-weight:bold;
color:#0F6CBD;
margin-bottom:15px;">

 Overall Environment Status

</div>

<table width="100%">

<tr>

<td width="25%" align="center">

<div style="font-size:13px;color:#666;">
Monitoring Status
</div>

<div style="font-size:18px;font-weight:bold;color:#28a745;">
Completed
</div>

</td>

<td width="25%" align="center">

<div style="font-size:13px;color:#666;">
Affected Servers
</div>

<div style="font-size:18px;font-weight:bold;color:#dc3545;">
$AffectedServers
</div>

</td>

<td width="25%" align="center">

<div style="font-size:13px;color:#666;">
Report Generated
</div>

<div style="font-size:15px;font-weight:bold;">
$(Get-Date -Format "dd-MMM-yyyy HH:mm")
</div>

</td>

<td width="25%" align="center">

<div style="font-size:13px;color:#666;">
Framework
</div>

<div style="font-size:15px;font-weight:bold;color:#0F6CBD;">
PowerShell 5.1
</div>

</td>

</tr>

</table>

</td>

</tr>

</table>

<h2 style="
background:#f4f8fc;
padding:12px;
border-left:6px solid #0F6CBD;
border-radius:6px;
color:#0F6CBD;
margin-top:20px;
margin-bottom:10px;">

Affected Servers ($AffectedServers)

</h2>

<table style="
width:100%;
border-collapse:collapse;
border:1px solid #d9e2ec;
border-radius:8px;
overflow:hidden;
box-shadow:0px 2px 8px rgba(0,0,0,0.08);">

<tr>

<th style="width:14%;">Target</th>

<th style="width:12%;">Health</th>

<th style="width:15%;">CPU</th>

<th style="width:15%;">Memory</th>

<th style="width:24%;">Disk</th>

<th style="width:10%;">Top Issue</th>

<th style="width:10%;">Uptime</th>

<th style="width:12%;">Last Updated</th>

</tr>

$rows

</table>

<br><br>

<table width="100%"
style="
border-collapse:collapse;
margin-top:25px;
border-top:3px solid #0F6CBD;">

<tr>

<td style="
padding:18px;
background:#f8fbff;">

<div style="
font-size:17px;
font-weight:bold;
color:#0F6CBD;
margin-bottom:15px;">

Health Status Legend

</div>

<table width="100%">

<tr>

<td width="33%">

<span style="
background:#d4edda;
color:#155724;
padding:6px 14px;
border-radius:18px;
font-weight:bold;">

Healthy

</span>

</td>

<td width="33%">

<span style="
background:#fff3cd;
color:#856404;
padding:6px 14px;
border-radius:18px;
font-weight:bold;">

Warning

</span>

</td>

<td width="34%">

<span style="
background:#f8d7da;
color:#721c24;
padding:6px 14px;
border-radius:18px;
font-weight:bold;">

Critical

</span>

</td>

</tr>

</table>

<br>

<div style="
font-size:17px;
font-weight:bold;
color:#0F6CBD;
margin-bottom:12px;">

Monitoring Thresholds

</div>

<table
width="100%"
style="font-size:13px;">

<tr>

<td>

<b>CPU Warning</b>

>=  75%

</td>

<td>

<b>CPU Critical</b>

>=  90%

</td>

</tr>

<tr>

<td>

<b>Memory Warning</b>

>=  75%

</td>

<td>

<b>Memory Critical</b>

>=  90%

</td>

</tr>

<tr>

<td>

<b>Disk Warning</b>

&lt; 20% Free

</td>

<td>

<b>Disk Critical</b>

&lt; 10% Free

</td>

</tr>

</table>

<br>

<div style="
border-top:1px solid #d9e2ec;
padding-top:15px;
font-size:12px;
color:#666;
text-align:center;">

This is an automated report generated by the
<b>Enterprise Server Health Monitoring Framework</b>.

<br><br>

Please do not reply to this email.

</div>

</td>

</tr>

</table>

</body>

</html>
"@

    return $html
}
# --- Configuration ---

# List of servers to monitor, separated by commas. Use "localhost" to monitor the machine where the script is run.
$serverlist = $MonitoringTarget -join ","
$AllowedServers = $MonitoringTarget
# Services to monitor (use Service Name or Display Name).
$servicesToMonitor = @(
    "Tanium*",
    "QualysAgent",
    "Splunk*",
    "WinDefend"
)

# Output directory for the CSV report
$outputDir = Join-Path $env:ProgramData "EnterpriseServerHealthMonitoring"

# ===========================================================================
# Monitoring Thresholds
# ===========================================================================

# CPU
$CPUWarningThreshold  = 75
$CPUCriticalThreshold = 95

# Memory
$MemoryWarningThreshold  = 75
$MemoryCriticalThreshold = 95

# Disk (Free Space %)
$DiskWarningThreshold  = 20
$DiskCriticalThreshold = 10

# Disk Alert Suppression (Hours)
$DiskSuppressionHours = 2
# Email delivery is intentionally disabled. This script writes local reports only.

# --- Script Logic ---

# Ensure output directory exists and resolve it to prevent path traversal.
if (-not (Test-Path -LiteralPath $outputDir -PathType Container)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}
$outputDir = (Resolve-Path -LiteralPath $outputDir).Path

# Convert comma-separated server list into an array and enforce the allowlist.
$ServerListArray = @($serverlist -split "," | ForEach-Object {
    $_.Trim()
} | Where-Object {
    $_ -ne ""
})
if ($ServerListArray.Count -eq 0) {
    throw "No servers specified. Update the serverlist variable and the allowlist."
}
foreach ($targetServer in $ServerListArray) {
    Assert-SafeServerTarget -ComputerName $targetServer -AllowedServers $AllowedServers
}

$TimeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outputFilePath = Join-Path $outputDir "HealthReport_${TimeStamp}.csv"
$Result = @()

# Define script block for remote execution (or local if $server is 'localhost')
$commandlist = {
    param($services)
   
    $targetLabel = "REDACTED"

    # 1. System Uptime
    $os = Get-CimInstance Win32_OperatingSystem
    $uptime = (New-TimeSpan -Start $os.LastBootUpTime -End (Get-Date)).ToString("dd\:hh\:mm\:ss")

   # =====================================================================
# CPU Utilization (Average of 3 Samples)
# =====================================================================

## =====================================================================
# CPU Utilization (Overall)
# =====================================================================

try
{
    $cpuLoad = Get-CimInstance Win32_Processor |
        Measure-Object LoadPercentage -Average |
        Select-Object -ExpandProperty Average

    $cpuLoad = [math]::Round($cpuLoad,2)
}
catch
{
    $cpuLoad = "N/A"
}

# =====================================================================
# Current Top 5 CPU Processes
# =====================================================================
try
{
   $liveCPUProcesses = Get-Counter "\Process(*)\% Processor Time" |
    Select-Object -ExpandProperty CounterSamples |
    Where-Object {
        $_.Status -eq 0 -and
        $_.InstanceName -notmatch "^Idle$|^_Total$"
    } |
    Sort-Object CookedValue -Descending |
    Select-Object -First 5

    $liveCPUSummary = (
        $liveCPUProcesses |
        ForEach-Object {
            "$($_.InstanceName.Split('#')[0]) : $([math]::Round($_.CookedValue,2))%"
        }
    ) -join "`r`n"
}
catch
{
    $liveCPUSummary = "Unable to retrieve live CPU usage."
}

# =====================================================================
# Top 5 CPU Time Processes
# =====================================================================

try
{
    $topCPUProcesses = Get-Process |
        Sort-Object CPU -Descending |
        Select-Object -First 5 `
            ProcessName,
            @{Name="CPUSeconds";Expression={[math]::Round($_.CPU,2)}}

    $topCPUProcessSummary = (
        $topCPUProcesses |
        ForEach-Object {
            "$($_.ProcessName) CPU:$($_.CPUSeconds)s"
        }
    ) -join "`r`n"
}
catch
{
    $topCPUProcessSummary = "Unable to retrieve CPU time information."
}

# =====================================================================
# Memory Utilization
# =====================================================================

try
{
   

    $totalRAM = [math]::Round($os.TotalVisibleMemorySize/1MB,2)
    $freeRAM  = [math]::Round($os.FreePhysicalMemory/1MB,2)

    $usedRAM = [math]::Round(($totalRAM-$freeRAM),2)

    $memPercent = [math]::Round((($usedRAM/$totalRAM)*100),2)
}
catch
{
    $memPercent = "N/A"
}

# =====================================================================
# Top 5 Memory Processes
# =====================================================================

try
{
    $topMemProcesses = Get-Process |
        Sort-Object WorkingSet64 -Descending |
        Select-Object -First 5 `
            ProcessName,
            @{Name="MemoryMB";Expression={[math]::Round($_.WorkingSet64/1MB,2)}}

    $topMemProcessSummary = (
        $topMemProcesses |
        ForEach-Object{
            "$($_.ProcessName) RAM:$($_.MemoryMB)MB"
        }
  ) -join "`r`n"
}
catch
{
    $topMemProcessSummary = "Unable to retrieve memory process information."
}

# =====================================================================
# Service Health Check
# =====================================================================

$svcResults = @()

foreach ($svcPattern in $services)
{
    try
    {
        # Search by Service Name OR Display Name
        $matchingServices = Get-CimInstance Win32_Service | Where-Object {

            $_.Name -like $svcPattern -or
            $_.DisplayName -like $svcPattern
        }

        if ($matchingServices)
        {
            foreach ($svc in $matchingServices)
            {
                $svcResults += [PSCustomObject]@{

                    ServiceName = $svc.Name
                    DisplayName = $svc.DisplayName
                    Status      = $svc.State
                    StartupType = $svc.StartMode
                }
            }
        }
        else
        {
            $svcResults += [PSCustomObject]@{

                ServiceName = $svcPattern
                DisplayName = $svcPattern
                Status      = "NOT FOUND"
                StartupType = "N/A"
            }
        }
    }
    catch
    {
        $svcResults += [PSCustomObject]@{

            ServiceName = $svcPattern
            DisplayName = $svcPattern
            Status      = "ERROR"
            StartupType = "UNKNOWN"
        }
    }
}

$formattedServiceResults = (
    $svcResults |
    ForEach-Object {
        "$($_.DisplayName) : $($_.Status) [Startup : $($_.StartupType)]"
    }
) -join "`r`n"

# -------------------------------------------------------------
# =====================================================================
# Disk Utilization
# =====================================================================

$diskInfo = @()
$folderSummary = "All drives have sufficient free space."

try
{
    $logicalDisks = Get-CimInstance Win32_LogicalDisk |
                    Where-Object { $_.DriveType -eq 3 }

    foreach ($disk in $logicalDisks)
    {
        $drive = $disk.DeviceID

        $totalGB = [math]::Round($disk.Size / 1GB,2)
        $freeGB  = [math]::Round($disk.FreeSpace / 1GB,2)
        $usedGB  = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB,2)

        if ($disk.Size -gt 0)
        {
            $percentFree = [math]::Round(($disk.FreeSpace / $disk.Size) * 100,2)
        }
        else
        {
            $percentFree = 0
        }

        $diskInfo += [PSCustomObject]@{
            Drive       = $drive
            TotalGB     = $totalGB
            UsedGB      = $usedGB
            FreeGB      = $freeGB
            PercentFree = $percentFree
        }
    }

    # ---------------------------------------------------------
    # Disk Summary
    # ---------------------------------------------------------

$diskSummary = (
    $diskInfo |
    ForEach-Object {
@"
Drive          : $($_.Drive)
Total Space    : $($_.TotalGB) GB
Used Space     : $($_.UsedGB) GB
Free Space     : $($_.FreeGB) GB
Free Space (%) : $($_.PercentFree)%
"@
    }
) -join "`r`n--------------------------`r`n"

}
catch
{
    $diskSummary = "Unable to retrieve disk information."
}# =====================================================================
# Build Output Object
# =====================================================================
# =====================================================================
# Overall Health
# =====================================================================


$overallHealth = "Healthy"

# Critical
if (
    ($cpuLoad -ne "N/A" -and $cpuLoad -ge $CPUCriticalThreshold) -or
    ($memPercent -ne "N/A" -and $memPercent -ge $MemoryCriticalThreshold) -or
    ($diskInfo | Where-Object { $_.PercentFree -lt $DiskCriticalThreshold })
)
{
    $overallHealth = "Critical"
}

# Warning
elseif (
    ($cpuLoad -ne "N/A" -and $cpuLoad -ge $CPUWarningThreshold) -or
    ($memPercent -ne "N/A" -and $memPercent -ge $MemoryWarningThreshold) -or
    ($diskInfo | Where-Object { $_.PercentFree -lt $DiskWarningThreshold })
)
{
    $overallHealth = "Warning"
}
[PSCustomObject]@{

    TargetLabel = $targetLabel
   
    ReportTime = Get-Date -Format "dd-MMM-yyyy HH:mm:ss"

    OverallHealth = $overallHealth

    Uptime = $uptime

    CPU_Utilization_Percent = $cpuLoad

    Current_CPU_Processes = $liveCPUSummary

Top_CPU_Time_Processes = $topCPUProcessSummary

    Memory_Utilization_Percent = $memPercent

    Top_5_Memory_Processes = $topMemProcessSummary

    Monitored_Services          = $formattedServiceResults

Disk_Summary                = $diskSummary

}
}

# Process each server
# =====================================================================

foreach ($server in $ServerListArray)
{
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Processing approved monitoring target." -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan

    try
    {
        if ($server.Trim().ToLower() -eq "localhost")
        {
            $output = & $commandlist -services $servicesToMonitor
        }
        else
        {
            # Verify WinRM connectivity
            if (-not (Test-WSMan -ComputerName $server -ErrorAction SilentlyContinue))
            {
                throw "Unable to connect using WinRM. Verify WinRM service, firewall rules, and network connectivity."
            }

            $output = Invoke-Command `
                        -ComputerName $server `
                        -ScriptBlock $commandlist `
                        -ArgumentList (,$servicesToMonitor) `
                        -ErrorAction Stop
        }

        $Result += $output

        Write-Host "SUCCESS: monitoring completed." -ForegroundColor Green
    }
   catch
{
    Write-Host ""
    Write-Host "ERROR : Monitoring failed for an approved target." -ForegroundColor Red
    # Detailed exception data should be written only to a restricted diagnostic log.

    continue
}
}
if ($Result.Count -eq 0)
{
    Write-Host ""
    Write-Host "No server health information collected." -ForegroundColor Red
    return
}

# =====================================================================
# Generate report only for Warning/Critical servers
# =====================================================================

$DashboardResults = $Result

$AlertResults = $Result | Where-Object {
    $_.OverallHealth -ne "Healthy"
}

if ($AlertResults.Count -eq 0)
{
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Green
    Write-Host "All monitored servers are healthy." -ForegroundColor Green
    Write-Host "No threshold breached." -ForegroundColor Green
    Write-Host "CSV report was not generated." -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green
    return
}

$Result = $AlertResults

Write-Host ""
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Execution Summary"
Write-Host "==================================="

foreach ($serverResult in $Result)
{
    switch ($serverResult.OverallHealth)
    {
        "Healthy"
        {
            Write-Host "HEALTHY result recorded." -ForegroundColor Green
        }

        "Warning"
        {
            Write-Host "WARNING result recorded." -ForegroundColor Yellow
        }

        "Critical"
        {
            Write-Host "CRITICAL result recorded." -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Monitoring Completed Successfully." -ForegroundColor Green

# ===========================================================================
# ===========================================================================
# Disk Alert Suppression
# ===========================================================================

# Keep only warning and critical results for the local report.
$Result = $AlertResults

# Export to CSV
try
{
    Write-Host "Output File: $outputFilePath" -ForegroundColor Cyan

    $Result | Export-Csv `
        -Path $outputFilePath `
        -NoTypeInformation `
        -Encoding UTF8 `
        -Force

    Write-Host "CSV created successfully." -ForegroundColor Green

$htmlReport = New-ServerHealthDashboard `
    -CsvPath $outputFilePath `
    -DashboardResults $DashboardResults
}
catch
{
    Write-Host "Export failed." -ForegroundColor Red
    Write-Verbose "The report export failed; detailed diagnostics belong in a restricted log."
}


Write-Host "Report saved locally; email delivery is disabled." -ForegroundColor Green
