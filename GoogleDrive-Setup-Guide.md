# Google Drive Upload Guide

## Overview

Google Drive upload is an optional server-side workflow for study deployments that require centralized CSV storage. The iOS app does not upload to Google Drive directly. Instead, it can send CSV data to a configured Flask endpoint, and the server can upload the file to Google Drive.

Manual iOS export remains the default behavior.

## Prerequisites

1. Google Cloud project.
2. Google Drive API enabled.
3. OAuth credentials downloaded as `credentials.json`.
4. A Google Drive folder approved for the study data.
5. A deployed server endpoint reachable from the iOS device.

## Server Configuration

Install dependencies:

```bash
cd simple-cloud-server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements_google.txt
```

Set environment variables:

```text
GOOGLE_DRIVE_FOLDER_ID=your-folder-id
GOOGLE_CREDENTIALS_FILE=credentials.json
GOOGLE_TOKEN_FILE=token.pickle
UPLOAD_FOLDER=uploaded_csvs
DEBUG=false
```

Run the server:

```bash
python google_drive_uploader.py
```

On first run, complete the OAuth authorization prompt. The generated token file is local server state and must not be committed.

## iOS Configuration

Set `CloudUploadURL` to the deployed endpoint:

```xml
<key>CloudUploadURL</key>
<string>https://example-study-server.org/upload</string>
```

Leave `CloudUploadURL` empty when the study workflow uses manual export.

## Expected Upload Flow

1. The iOS app creates a CSV file.
2. If `CloudUploadURL` is configured, the app sends the CSV payload to the server.
3. The server validates and stores a local backup.
4. The server uploads the file to the configured Google Drive folder.
5. If the cloud endpoint is unavailable, the app falls back to manual share export.

## Data Governance Considerations

Before using Google Drive for study data, confirm:

- Whether participant identifiers are present in exported CSV files.
- Whether the Google Drive folder is approved for the protocol.
- Who can access the folder.
- How files are retained and removed.
- Whether audit and backup requirements are satisfied.

## Troubleshooting

`credentials.json not found`: Confirm that `GOOGLE_CREDENTIALS_FILE` points to the downloaded OAuth credentials file.

`Permission denied`: Confirm that the authenticated Google account can create files in the configured folder.

`Upload failed`: Check server logs, Google Drive API quota, folder ID, and network reachability.

`iOS cannot reach server`: Use a deployed HTTPS endpoint or a local network address reachable from the physical device. `localhost` on the device is not the development machine.
