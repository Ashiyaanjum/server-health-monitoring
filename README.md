# Enterprise Server Health Monitoring

A hardened PowerShell script for local report generation from Windows server health checks. It collects CPU, memory, disk, uptime, process, and service metrics, then generates a CSV/HTML report for warning and critical results.

## Contents

- `ServerHealthMonitoring.ps1` — hardened monitoring script.
- `SECURITY.md` — security requirements and reporting guidance.
- `.gitignore` — prevents generated reports, state files, and local secrets from being committed.
- `DEPLOYMENT_GUIDE.md` — professional setup, runtime-parameter, permissions, scheduling, and troubleshooting guide.
- `tests/Invoke-MockMonitoringTests.ps1` — dependency-free mock and privacy validation harness.

## Privacy behavior

This repository version intentionally contains **no hostname, email address, personal identifier, process ID, or IP address**. Monitoring targets must be supplied at runtime. Reports use the fixed label `REDACTED` instead of a host identity, and process reports exclude process IDs.

Email delivery is intentionally disabled. The script writes reports locally and does not contain SMTP configuration or recipient data.

## Required runtime input

Supply one or more approved monitoring targets when invoking the script. The target values are not stored in the script or repository:

```powershell
.\ServerHealthMonitoring.ps1 -MonitoringTarget <TARGET_PROVIDED_AT_RUNTIME>
```

The script validates the runtime target format and uses the supplied values as the execution allowlist for that run. Do not place personal data, email addresses, IP literals, or credentials in command history or scheduled-task arguments. Use an approved protected input mechanism for unattended operation.

## Prerequisites

The script is intended for Windows PowerShell 5.1 on a managed Windows host with:

1. WinRM enabled and authorized for the runtime-supplied monitoring targets.
2. An account with only the minimum permissions required to query monitored systems.
3. Permission to create and write under `%ProgramData%`.

## Running

Run from an appropriately authorized PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\ServerHealthMonitoring.ps1 -MonitoringTarget <TARGET_PROVIDED_AT_RUNTIME>
```

The execution-policy command affects only the current PowerShell process. Follow organizational policy for code signing and production execution; prefer a signed script and a restricted execution policy in managed environments.

If no warning or critical result exists, no report is generated.

## Generated data

The script writes generated CSV and state data under:

```text
%ProgramData%\EnterpriseServerHealthMonitoring
```

Reports contain operational metrics, process names, service names, uptime, and disk capacity. Treat generated reports as sensitive infrastructure data and do not commit generated CSV, HTML, JSON, or log files.

## Operational recommendations

Use a dedicated least-privilege identity, restrict WinRM access to approved targets, and configure NTFS permissions on the output directory so only the service identity and approved administrators can read or modify files. Test first in a non-production environment.
