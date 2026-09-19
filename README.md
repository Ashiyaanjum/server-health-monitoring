# Enterprise Server Health Monitoring

A hardened PowerShell script for monitoring Windows server health and sending alert reports. It collects CPU, memory, disk, uptime, process, and service information, then generates a CSV/HTML report for servers that breach configured thresholds.

## Contents

- `ServerHealthMonitoring.ps1` — hardened monitoring script.
- `SECURITY.md` — security requirements and reporting guidance.
- `.gitignore` — prevents generated reports, state files, and local secrets from being committed.

## Security posture

The script is designed to avoid storing credentials in source control. It includes the following controls:

- Approved-server allowlisting and target-format validation before WinRM execution.
- Runtime SMTP credential acquisition with `Get-Credential`.
- TLS-required SMTP configuration on port 587 by default.
- Placeholder SMTP and recipient values that cause the script to stop until configured.
- One-way aliases instead of raw hostnames in generated reports.
- HTML encoding of dynamic values before report insertion.
- Safe output filename construction and a `%ProgramData%` output directory.
- Reduced diagnostic disclosure and no embedded personal identifiers.

## Required configuration

Before running the script, edit the configuration section and replace the placeholders:

```powershell
$serverlist = "SERVER01"
$AllowedServers = @("SERVER01")
$SMTPServer = "smtp.example.com"
$EmailFrom = "server-monitor@example.com"
$EmailTo = @("operations@example.com")
```

Keep `$serverlist` restricted to values present in `$AllowedServers`. Use an approved SMTP relay that supports authenticated TLS on port 587. The script prompts for the SMTP credential at runtime; do not add a password to the script or repository.

The placeholder values are intentionally rejected by the script:

- `SERVER_NAME`
- `SMTP_SERVER`
- `example.invalid` email addresses

## Prerequisites

The script is intended for Windows PowerShell 5.1 on a managed Windows host with:

1. WinRM enabled and authorized for the approved monitoring targets.
2. Network access to the approved servers and SMTP relay.
3. An account with only the minimum permissions required to query the monitored systems.
4. Permission to create and write under `%ProgramData%`.
5. An SMTP credential authorized to send from the configured sender address.

## Running

Run from an elevated or otherwise appropriately authorized PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\ServerHealthMonitoring.ps1
```

The execution-policy command affects only the current PowerShell process. Follow organizational policy for code signing and production execution; prefer a signed script and a restricted execution policy in managed environments.

The script prompts for the SMTP credential only after monitoring and report generation are complete. If no warning or critical result exists, no report is generated and no email is sent.

## Generated data

The script writes generated CSV and state data under:

```text
%ProgramData%\EnterpriseServerHealthMonitoring
```

Reports contain operational information such as process names, service names, uptime, disk capacity, and health metrics. Treat generated reports as sensitive infrastructure data. Do not commit generated CSV, HTML, JSON, or log files to GitHub.

## Operational recommendations

Use a dedicated service identity with least privilege, restrict WinRM access to the allowlisted targets, and configure NTFS permissions on the output directory so only the service identity and approved administrators can read or modify the files. Test first in a non-production environment. For unattended scheduling, replace the interactive credential prompt with an approved enterprise secret-management solution; never place the credential in a scheduled-task argument, plaintext file, or Git repository.

## Repository privacy

This repository is intended to remain private. Review the repository visibility and organization policies after creation. Rotate any credential immediately if a secret is ever committed, even if the commit is later deleted.
