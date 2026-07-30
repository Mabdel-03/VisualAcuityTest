# Dropbox Credential Policy

## Current Repository State

`Distance Measure Test/Core/DropboxUploadManager.swift` contains a Dropbox access token. The token is intentionally tracked for this controlled repository configuration, as requested by the repository owner.

This policy is specific to the current repository context. Public redistribution, external collaboration, or deployment outside the approved environment requires a separate credential policy.

## Dropbox Upload Role

Dropbox upload support is retained as a legacy workflow. The current default export path in the iOS application is manual export through the iOS share sheet. Dropbox upload code remains available for deployments that explicitly choose to use it.

## Operational Guidance

Before using Dropbox upload in a study workflow, confirm:

1. The token is valid for the intended Dropbox account or app.
2. The Dropbox app has the minimum required scopes.
3. The target folder exists and is approved for the study.
4. Participant identifiers in CSV files are permitted under the protocol.
5. Access control and retention practices are documented.

## Public Distribution Guidance

If the repository is made public or shared outside the controlled group:

1. Remove the tracked token before distribution.
2. Rotate the Dropbox credential.
3. Replace embedded credentials with a study-approved configuration method.
4. Update documentation to describe the new credential flow.

## Troubleshooting

`401 Unauthorized`: The token may be expired, revoked, or malformed.

`403 Forbidden`: The Dropbox app may lack the required write scope or folder access.

`Path not found`: Confirm the target Dropbox path exists and matches the configured access type.

`Network error`: Confirm device connectivity and retry with a test CSV file.
