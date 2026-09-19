# Deployment Guide: Runtime-Parameter Server Monitoring

## 1. Purpose

This guide describes how to deploy and run `ServerHealthMonitoring.ps1` without storing monitoring targets or identifying information in the script. The repository version writes reports locally, uses the fixed label `REDACTED` in report output, excludes process IDs, and does not send email.

> **Privacy requirement:** Monitoring targets must be supplied at runtime. Do not commit target names, personal data, credentials, email addresses, IP addresses, or generated reports to the repository.

## 2. Prerequisites

Run the script from a managed Windows computer with Windows PowerShell 5.1. The execution account must have the minimum permissions required to query the approved monitoring targets. It must also be authorized to use Windows Remote Management (WinRM) when remote monitoring is required and must have write permission under `%ProgramData%`.

The infrastructure team should approve the WinRM relationship before deployment. The monitoring computer must be able to reach each approved target, and each target must permit the required remote CIM and performance-counter queries.

Before production use, test the script in a non-production environment. Follow organizational requirements for script signing, application control, endpoint protection, and PowerShell logging.

## 3. Obtain and protect the script

Clone or download the private repository through an approved GitHub process. Place `ServerHealthMonitoring.ps1` in a protected local directory. Do not place the script in a shared, user-writable directory.

After transfer, verify that the file is the expected version. Keep generated reports and local configuration outside the repository.

## 4. Runtime parameter

The script requires one parameter:

```powershell
-MonitoringTarget <TARGET_PROVIDED_AT_RUNTIME>
```

The parameter accepts one or more approved target values. These values are used only for the current execution. They are not written into the script, report label, report filename, or repository.

For one target:

```powershell
.\ServerHealthMonitoring.ps1 -MonitoringTarget '<TARGET_PROVIDED_AT_RUNTIME>'
```

For multiple targets:

```powershell
.\ServerHealthMonitoring.ps1 -MonitoringTarget '<TARGET_A>','<TARGET_B>'
```

Use only target values approved by the infrastructure team. Do not substitute personal names, email addresses, credentials, or unapproved systems.

## 5. First-run deployment

Open PowerShell under the approved execution account. Change to the directory containing the script, then run a test against a non-production target:

```powershell
Set-Location '<PROTECTED_SCRIPT_DIRECTORY>'
.\ServerHealthMonitoring.ps1 -MonitoringTarget '<TEST_TARGET_PROVIDED_AT_RUNTIME>'
```

The script validates the supplied target format and uses the runtime values as the allowlist for that run. It then checks WinRM connectivity, collects health metrics, and creates a report only when a warning or critical condition is detected.

Reports and local state data are written under:

```text
%ProgramData%\EnterpriseServerHealthMonitoring
```

The report does not contain the actual target label. It uses `REDACTED` so that the generated file can be handled without exposing a hostname.

## 6. Verify a successful run

Confirm the following outcomes after the test run:

1. Monitoring completes without printing a target value to the console.
2. The output directory exists under `%ProgramData%`.
3. Any generated report uses a generic `HealthReport_` filename.
4. The report uses `REDACTED` as the target label.
5. The report contains health metrics and process names but no process IDs.
6. No target value, credential, email address, personal identifier, or IP address appears in the script or repository.

Treat reports as sensitive infrastructure data even though identifying target labels are removed. Process names, service names, uptime, and capacity metrics can still reveal operational details.

## 7. File and directory permissions

Restrict the script directory so that ordinary users cannot modify the script. Restrict `%ProgramData%\EnterpriseServerHealthMonitoring` so that only the monitoring identity and approved administrators can read or change reports and state files.

Do not grant broad write permission to the script directory. A user who can modify the script can change the commands executed remotely.

## 8. Scheduling guidance

For a scheduled task, use a dedicated least-privilege identity. Supply runtime targets through an approved protected configuration mechanism rather than hardcoding them in the script or placing sensitive values in a shared task definition.

If the task definition contains target values, restrict access to the task and its configuration. Do not store credentials in command-line arguments, plaintext files, or repository variables unless the organization has explicitly approved that storage method.

Example scheduled invocation using a runtime placeholder:

```powershell
PowerShell.exe -NoProfile -NonInteractive -File '<PROTECTED_SCRIPT_DIRECTORY>\ServerHealthMonitoring.ps1' -MonitoringTarget '<TARGET_PROVIDED_AT_RUNTIME>'
```

The current script does not send email. Use an approved separate notification system if alert delivery is required. Any future notification integration must preserve the repository rule that no personal email address or credential is stored in source control.

## 9. Troubleshooting

### Target validation fails

Confirm that the runtime target is supplied and follows the approved target naming rules. Confirm that the value is authorized for the current run. Do not modify the script to bypass validation.

### WinRM connectivity fails

Ask the infrastructure team to verify WinRM configuration, firewall policy, endpoint authorization, and the permissions of the execution account. The script intentionally avoids printing the target value or detailed exception data.

### No report is created

The script creates a report only when at least one monitored target has a warning or critical result. A healthy run ends without generating a report.

### The output directory cannot be written

Verify that the execution identity can create and write files under `%ProgramData%\EnterpriseServerHealthMonitoring`. Do not solve this by granting write access to all users.

### The report contains unexpected operational detail

Restrict access to the report directory and treat the report as sensitive infrastructure data. Do not publish generated reports to GitHub or attach them to public support requests.

## 10. Removal and incident response

To remove a deployment, stop the scheduled task, delete the protected script directory, and remove generated reports according to the organization’s retention policy.

If a target value or secret is accidentally committed, remove it from repository history and immediately rotate the affected credential or access authorization. Treat the value as exposed even if the commit is later deleted.

## References

[1]: https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_powershell_exe "PowerShell about_PowerShell_exe documentation"

[2]: https://learn.microsoft.com/windows/win32/winrm/portal "Windows Remote Management documentation"

[3]: https://learn.microsoft.com/powershell/module/microsoft.powershell.security/about/about_execution_policies "PowerShell execution policies documentation"
