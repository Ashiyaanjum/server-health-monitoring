# Mock Test Suite

`Invoke-MockMonitoringTests.ps1` is a dependency-free PowerShell test harness for the monitoring repository. It does not contact WinRM, query a real computer, send email, or require credentials.

## What it validates

The harness checks the following behavior and repository contracts:

- Healthy, warning, critical, disk, and multiple-issue classifications.
- Redacted target labels in mock results.
- Exclusion of process IDs from process summaries.
- Creation of mock CSV and HTML reports.
- Presence of the `REDACTED` label in generated output.
- Absence of email addresses, IPv4 literals, personal profile paths, and process-ID patterns.
- Presence of runtime-target validation and remote-monitoring controls in the production script.

## Run the tests

From Windows PowerShell 5.1, run:

```powershell
Set-Location '<REPOSITORY_DIRECTORY>'
.\tests\Invoke-MockMonitoringTests.ps1
```

To specify a different production script path:

```powershell
.\tests\Invoke-MockMonitoringTests.ps1 -ScriptPath '<SCRIPT_PATH>'
```

To specify a temporary output location:

```powershell
.\tests\Invoke-MockMonitoringTests.ps1 -OutputDirectory '<TEMPORARY_TEST_DIRECTORY>'
```

The harness removes its temporary output directory when it finishes. A zero exit code indicates that all checks passed. A nonzero exit code indicates a failed assertion or harness error.

## Scope and limitations

This is a mock and static-validation suite. It verifies report contracts and deterministic threshold logic, but it does not prove that WinRM, CIM, performance counters, permissions, or the target operating system are configured correctly. Perform a separate non-production integration test before enabling scheduled monitoring.
