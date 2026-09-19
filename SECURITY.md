# Security Policy

## Supported version

The latest version on the default branch is the supported version.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Report it privately through the repository's GitHub security advisories feature or to the repository owner through an approved private channel.

Do not include passwords, SMTP credentials, access tokens, host inventories, IP addresses, or report attachments in a public issue.

## Secret-handling requirements

Never commit credentials or generated monitoring output. If a secret is committed or exposed, revoke or rotate it immediately, remove it from the working tree and repository history, and investigate access logs.

The script should use least-privilege identities, approved WinRM targets, authenticated TLS-protected SMTP, and restricted permissions on its output directory.
