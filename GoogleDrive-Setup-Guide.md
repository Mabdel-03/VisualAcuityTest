# Google Drive Integration Setup Guide

## Overview
This guide explains how to set up Google Drive integration for the Visual Acuity Test app's data collection feature. CSVs will be automatically uploaded to a shared Google Drive folder instead of being emailed.

## Prerequisites
1. Google Cloud Console account
2. Xcode project with Google Drive dependencies added
3. Google Drive account for data storage

## Setup Steps

### Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "New Project" or select existing project
3. Name: "Visual Acuity Test Data Collection"
4. Note the Project ID for later use

### Step 2: Enable Google Drive API

1. In Google Cloud Console, go to "APIs & Services" > "Library"
2. Search for "Google Drive API"
3. Click on "Google Drive API" and click "Enable"
4. Also enable "Google Sign-In API" if not already enabled

### Step 3: Create OAuth 2.0 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth 2.0 Client IDs"
3. Application type: "iOS"
4. Name: "Visual Acuity Test iOS App"
5. Bundle ID: Your app's bundle identifier (e.g., `com.ohsu.visualacuitytest`)
6. Download the configuration file

### Step 4: Add GoogleService-Info.plist to Xcode

1. Rename the downloaded file to `GoogleService-Info.plist`
2. Drag it into your Xcode project root
3. Make sure "Add to target" is checked for your main app target
4. Verify the file appears in your project navigator

### Step 5: Configure URL Scheme

Add to your `Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_CLIENT_ID` and `YOUR_REVERSED_CLIENT_ID` with values from GoogleService-Info.plist.

### Step 6: Create Shared Google Drive Folder

1. Go to [Google Drive](https://drive.google.com)
2. Create a new folder named "Visual Acuity Test Data Collection"
3. Right-click the folder > "Share"
4. Add mabdel03@mit.edu with "Editor" permissions
5. Copy the folder ID from the URL (the long string after `/folders/`)
6. Update the folder ID in DataCollectionViewController.swift:

```swift
file.parents = ["YOUR_FOLDER_ID_HERE"] // Replace with actual folder ID
```

### Step 7: Update AppDelegate for Google Sign-In

Add to your `AppDelegate.swift`:

```swift
import GoogleSignIn

func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return GIDSignIn.sharedInstance.handle(url)
}
```

### Step 8: Test the Integration

1. Build and run the app on a physical device
2. Navigate to Data Collection
3. Complete the 25-letter test
4. When prompted, sign in to Google account
5. Grant Drive access permissions
6. Verify CSV appears in the shared Drive folder

## Folder Structure in Google Drive

The shared folder will contain CSV files with this naming pattern:
```
Visual Acuity Test Data Collection/
├── 2024-01-15-143022.csv
├── 2024-01-15-145133.csv
├── 2024-01-16-091245.csv
└── ...
```

Each CSV contains:
- `Letter_Displayed`: The letter shown to the user
- `Transcribed_Text`: What the speech recognition heard
- `Mapped_Result`: What the current algorithm mapped it to

## Benefits of Google Drive Integration

✅ **Automatic Cloud Storage**: No more manual email handling  
✅ **Shared Access**: Multiple researchers can access data immediately  
✅ **Version History**: Google Drive tracks file versions automatically  
✅ **Real-time Sync**: Data available instantly across devices  
✅ **Organized Storage**: All data in one centralized location  
✅ **Backup & Recovery**: Google's enterprise-grade data protection  

## Troubleshooting

### Common Issues:

1. **"GoogleService-Info.plist not found"**
   - Ensure the file is added to the Xcode project
   - Check that it's included in the app target

2. **"Authentication failed"**
   - Verify OAuth client ID matches bundle identifier
   - Check URL scheme configuration in Info.plist

3. **"Upload failed"**
   - Verify internet connection
   - Check Google Drive API quota limits
   - Ensure folder ID is correct and accessible

4. **"Permission denied"**
   - Verify the shared folder has correct permissions
   - Check that the Google account has Drive access

### Fallback Behavior:

If Google Drive upload fails, the app automatically falls back to the original email functionality, ensuring data is never lost.

## Security Considerations

- OAuth 2.0 provides secure authentication
- Only minimal Drive scope requested (file creation only)
- No access to existing Drive files
- Data encrypted in transit via HTTPS
- Google Drive provides enterprise-grade security

## Future Enhancements

This Google Drive integration provides a foundation for:
- Real-time collaboration between researchers
- Automated data analysis scripts
- Integration with Google Sheets for live analytics
- Batch processing of collected data
- Easy export to other analysis tools

The Google Drive integration serves as an excellent intermediate step toward the full cloud backend architecture outlined in Backend-Implementation-Context.txt.
