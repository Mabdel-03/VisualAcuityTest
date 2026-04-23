# Dropbox Non-Expiring Access Token Setup Guide

This guide will help you set up a Dropbox access token that never expires for the Visual Acuity Test app.

## ⚠️ Current Issue

Your current token starts with `sl.u.` which means it's a **short-lived token** that will expire in a few hours. You need to replace it with a **long-lived (non-expiring) token**.

## 📝 Step-by-Step Instructions

### Step 1: Access Dropbox App Console

1. Go to: [https://www.dropbox.com/developers/apps](https://www.dropbox.com/developers/apps)
2. Sign in with your Dropbox account

### Step 2: Select or Create Your App

**Option A: If you already have an app**
- Click on your existing app from the list

**Option B: If you need to create a new app**
1. Click the **"Create app"** button
2. Choose the following settings:
   - **Choose an API**: Select **"Scoped access"**
   - **Choose the type of access**: 
     - Select **"Full Dropbox"** (if you want access to entire Dropbox)
     - Or **"App folder"** (if you want isolated folder access)
   - **Name your app**: e.g., "OHSU Visual Acuity Test"
3. Click **"Create app"**

### Step 3: Configure App Permissions

1. Go to the **"Permissions"** tab
2. Enable the following scopes:
   - ✅ `files.content.write` (Required - to upload CSV files)
   - ✅ `files.content.read` (Optional - to read files if needed)
3. Click **"Submit"** at the bottom to save your changes

### Step 4: Generate Non-Expiring Access Token

1. Go to the **"Settings"** tab
2. Scroll down to the **"OAuth 2"** section
3. Find **"Access token expiration"**
4. **CRITICAL**: Make sure it's set to **"No expiration"**
5. Click the **"Generate"** button under "Generated access token"
6. **Copy the entire token** that appears

**Important Notes:**
- The token will be very long (several hundred characters)
- It should **NOT** start with `sl.` - if it does, it's still a short-lived token
- Keep this token secure - anyone with this token can access your Dropbox

### Step 5: Update the App Code

1. Open the file: `Distance Measure Test/DropboxUploadManager.swift`
2. Find line 15 where it says: `private let accessToken = "YOUR_TOKEN_HERE"`
3. Replace `"YOUR_TOKEN_HERE"` with your new token in quotes
4. Save the file

Example:
```swift
private let accessToken = "your-very-long-dropbox-token-here"
```

### Step 6: Test the Integration

1. Build and run the app
2. Complete a test trial
3. Check that the CSV file uploads successfully to your Dropbox folder
4. Verify the file appears in: `/Mahmoud Abdelmoneum/OHSU/Clinical_Trials/Landolt_C_Only_Trials/`

## 🔒 Security Best Practices

1. **Never commit the token to public repositories**
   - Keep `DropboxUploadManager.swift` in `.gitignore` if needed
   - Or use environment variables/configuration files

2. **Regularly review app permissions**
   - Go to your Dropbox App Console periodically
   - Check which apps have access to your account

3. **Revoke tokens if compromised**
   - If you suspect the token is exposed, revoke it immediately
   - Generate a new token from the App Console

4. **Use minimal permissions**
   - Only enable the permissions your app actually needs

## 🆘 Troubleshooting

### Token Expired Error
- If you get "expired_access_token" error, your token has expired
- Generate a new token and make sure "No expiration" is selected

### Upload Failed (401 Unauthorized)
- Check that the token is correctly copied (no extra spaces)
- Verify the token hasn't been revoked in the App Console
- Make sure permissions are properly set

### Upload Failed (403 Forbidden)
- Check that `files.content.write` permission is enabled
- Verify the target folder path exists in your Dropbox

### Path Not Found Error
- Verify the folder path exists: `/Mahmoud Abdelmoneum/OHSU/Clinical_Trials/Landolt_C_Only_Trials/`
- Create the folder manually in Dropbox if it doesn't exist
- Check for typos in the folder path

## 📚 Additional Resources

- [Dropbox API Documentation](https://www.dropbox.com/developers/documentation)
- [OAuth Guide](https://www.dropbox.com/developers/reference/oauth-guide)
- [Access Token Types](https://www.dropbox.com/developers/reference/auth-types)

## 📞 Support

If you encounter issues:
1. Check the Xcode console for detailed error messages
2. Verify your token in the Dropbox App Console
3. Test the token using Dropbox's API Explorer

