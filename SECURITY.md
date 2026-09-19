# Security Policy

## Privacy requirement

The repository must not contain hostnames, email addresses, personal identifiers, process IDs, IP literals, passwords, tokens, or generated monitoring reports. Monitoring targets are runtime-only inputs and must not be committed.

## Supported version

The latest version on the default branch is the supported version.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Report it privately through the repository's GitHub security advisories feature or to the repository owner through an approved private channel. Do not include credentials, target inventories, runtime inputs, or report attachments in a public issue.

## Secret-handling requirements

Never commit credentials or generated monitoring output. If sensitive data is exposed, revoke or rotate it immediately, remove it from repository history, and investigate access logs.
