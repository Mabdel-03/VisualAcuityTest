# MIT Dropbox API Access Guidance

## Purpose

This document provides a neutral template for requesting Dropbox API support for a controlled research workflow. It is relevant when a Dropbox Business account restricts OAuth app creation or token generation to team administrators.

## When to Use This Guide

Use this guide if:

1. Dropbox upload is selected for a study workflow.
2. The account is managed by MIT Dropbox Business.
3. The account holder cannot create a Dropbox API app or token directly.

Manual iOS export and optional Google Drive server upload are alternative workflows.

## Request Template

```text
Subject: Dropbox API access request for research data upload workflow

Hello MIT IS&T team,

I am working on an OHSU research software project that may require programmatic upload of CSV data files to a Dropbox folder associated with my MIT account.

Account:
mabdel03@mit.edu

Project:
OHSU Visual Acuity Test iOS research application

Purpose:
Upload CSV files generated during controlled visual acuity data collection.

Requested capability:
Dropbox API access for file upload only, with the minimum scope needed for CSV file creation in the approved folder.

Requested scope:
files.content.write

Target path:
/Mahmoud Abdelmoneum/OHSU/Clinical_Trials/Landolt_C_Only_Trials/

Please advise whether MIT can provide an approved Dropbox OAuth app, a token provisioning process, or an alternative MIT-approved storage workflow for this use case.

Thank you,
Mahmoud Abdelmoneum
mabdel03@mit.edu
```

## Information to Confirm

Before requesting access, confirm:

1. Whether the exported CSV files contain participant identifiers.
2. Whether the study protocol permits Dropbox storage.
3. Whether the folder access list is limited to approved personnel.
4. Whether token storage and rotation are documented.
5. Whether MIT has a preferred storage service for the data category.

## Current Repository Credential Note

The current repository intentionally tracks the Dropbox token in `DropboxUploadManager.swift` for a controlled configuration. This should be reconsidered before broader sharing or public distribution.

## Alternatives

If Dropbox API access is not approved, consider:

1. Manual iOS share export.
2. Server-side Google Drive upload using the optional Flask service.
3. A storage service explicitly approved by the institution or study protocol.
4. Local export followed by documented manual transfer.
