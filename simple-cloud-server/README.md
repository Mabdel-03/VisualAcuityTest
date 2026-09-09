# Simple Cloud Upload Server for Visual Acuity Test

This is a lightweight Python server that receives CSV uploads from your iOS app and saves them directly to your Google Drive folder.

## Quick Setup (5 minutes)

### Option 1: Direct Google Drive Upload (Recommended)

1. **Install Python dependencies:**
   ```bash
   cd simple-cloud-server
   pip install -r requirements_google.txt
   ```

2. **Set up Google Drive API credentials:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing
   - Enable Google Drive API
   - Create OAuth 2.0 credentials (Desktop application type)
   - Download `credentials.json` and place in this folder

3. **Run the server:**
   ```bash
   python google_drive_uploader.py
   ```

4. **Authorize on first run:**
   - Server will show an authorization URL
   - Visit the URL and grant permissions
   - Copy the authorization code back to the terminal
   - Credentials will be saved for future use

5. **Update iOS app:**
   - Change `cloudUploadURL` to your server address (e.g., `http://your-server:5000/upload`)
   - For local testing: `http://localhost:5000/upload`

### Option 2: Simple File Server (No Google API setup needed)

1. **Install basic dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Configure email (optional):**
   - Copy `.env.example` to `.env`
   - Update with your email settings

3. **Run simple server:**
   ```bash
   python app.py
   ```

## Deployment Options

### Local Testing
```bash
python google_drive_uploader.py
# Server runs at http://localhost:5000
```

### Cloud Deployment (Heroku)
```bash
# Create Heroku app
heroku create visual-acuity-upload-server

# Set environment variables
heroku config:set GOOGLE_DRIVE_FOLDER_ID=1gQNIG23hqthx7XncvycEDuJPaf8yV012

# Deploy
git add .
git commit -m "Add cloud upload server"
git push heroku main
```

### Cloud Deployment (Railway/Render)
1. Connect your GitHub repository
2. Set environment variables in the platform
3. Deploy automatically

## Update iOS App

Update the `cloudUploadURL` in `DataCollectionViewController.swift`:

```swift
// For local testing
private let cloudUploadURL = "http://localhost:5000/upload"

// For production deployment
private let cloudUploadURL = "https://your-app-name.herokuapp.com/upload"
```

## How It Works

1. **iOS app completes data collection** (25 letters)
2. **Generates CSV** with letter/transcription/mapping data
3. **Sends HTTP POST** to your cloud server
4. **Server uploads CSV** directly to your Google Drive folder
5. **Returns success** to iOS app
6. **CSV appears instantly** in your shared Drive folder

## Benefits

✅ **Direct Google Drive integration** - Files appear in your specified folder  
✅ **Instant access** - No email delays or manual file handling  
✅ **Automatic organization** - All data in one place with timestamps  
✅ **Backup storage** - Server keeps local copies as backup  
✅ **Real-time collaboration** - Multiple researchers can access immediately  
✅ **Simple deployment** - Can run on any cloud platform  

## Monitoring

- **Health check**: `GET /health`
- **List files**: `GET /files` (local backups)
- **Server logs**: All operations logged with timestamps

## Security

- OAuth 2.0 authentication with Google
- HTTPS encryption for data transfer
- Minimal permissions (file creation only)
- No access to existing Drive files

Your Google Drive folder will receive CSV files with names like:
- `2024-01-15-143022.csv`
- `2024-01-15-145133.csv`
- etc.

Each containing the letter/transcription/mapping data for algorithm optimization!
