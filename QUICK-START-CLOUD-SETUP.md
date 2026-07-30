# Optional Cloud Upload Setup

## Summary

The iOS application exports CSV files manually by default. Cloud upload is optional and should be enabled only when a study deployment has an approved endpoint. The app reads the endpoint from `CloudUploadURL`; an empty value disables automatic upload.

## Local Server Setup

```bash
cd simple-cloud-server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements_google.txt
python app.py
```

The default local endpoint is:

```text
http://localhost:5000/upload
```

This address is local to the machine running the server. A physical iOS device will not reach it unless the device can access the host over the local network and the app is configured with that reachable address.

## Enable Upload in the iOS App

Set `CloudUploadURL` in `Distance-Measure-Test-Info.plist` or through target build settings:

```xml
<key>CloudUploadURL</key>
<string>https://example-study-server.org/upload</string>
```

Leave the string empty to keep manual export as the default.

## Server Contract

The server accepts JSON:

```json
{
  "filename": "example.csv",
  "content": "Letter_Displayed,Transcribed_Text,Mapped_Result\nC,see,C\n",
  "timestamp": "2026-07-08T00:00:00Z",
  "source": "visual_acuity_ios_app"
}
```

Expected behavior:

1. Validate that the request is JSON.
2. Validate required fields.
3. Reject filenames with path components.
4. Accept only `.csv` uploads.
5. Store the CSV in the configured upload directory.
6. Return a JSON response with upload status and processed row count.

## Verification

```bash
curl http://localhost:5000/health
```

```bash
curl -X POST http://localhost:5000/upload \
  -H "Content-Type: application/json" \
  -d '{"filename":"example.csv","content":"a,b\n1,2\n","timestamp":"2026-07-08T00:00:00Z","source":"manual_test"}'
```

For production or study use, verify network reachability from the iOS device, HTTPS configuration, storage permissions, logging policy, and data retention requirements.
