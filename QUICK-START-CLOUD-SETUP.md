# Quick Start: Google Drive Cloud Upload Setup

## 🎯 Goal
Upload CSV data from your iOS app directly to your Google Drive folder: 
**https://drive.google.com/drive/folders/1gQNIG23hqthx7XncvycEDuJPaf8yV012**

## 🚀 5-Minute Setup

### Step 1: Set up Google Cloud API (2 minutes)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create new project: "Visual Acuity Upload Server"
3. Enable **Google Drive API**
4. Create **OAuth 2.0 credentials** (Desktop application)
5. Download as `credentials.json`

### Step 2: Deploy Upload Server (2 minutes)

```bash
# Navigate to server directory
cd simple-cloud-server

# Run setup script
./deploy.sh

# Place your credentials.json file here
# (downloaded from Google Cloud Console)

# Start the server
python google_drive_uploader.py
```

### Step 3: Update iOS App (1 minute)

The iOS app is already configured with your folder ID: `1gQNIG23hqthx7XncvycEDuJPaf8yV012`

Just update the server URL in `DataCollectionViewController.swift`:

```swift
// For local testing
private let cloudUploadURL = "http://localhost:5000/upload"

// For production (after deploying to cloud)
private let cloudUploadURL = "https://your-app-name.herokuapp.com/upload"
```

## 🔄 How It Works

```
iOS App → HTTP POST → Python Server → Google Drive API → Your Folder
```

1. User completes 25-letter data collection
2. App sends CSV data to your server
3. Server uploads directly to your Google Drive folder
4. CSV appears instantly in: https://drive.google.com/drive/folders/1gQNIG23hqthx7XncvycEDuJPaf8yV012

## 📁 What You'll See in Google Drive

Files will appear with names like:
- `2024-01-15-143022.csv`
- `2024-01-15-145133.csv`

Each containing:
```csv
Letter_Displayed,Transcribed_Text,Mapped_Result
C,see,C
D,dee,D
F,eff,F
...
```

## 🌐 Deployment Options

### Local Development
- Run on your computer: `python google_drive_uploader.py`
- Access via: `http://localhost:5000/upload`
- Good for testing

### Cloud Deployment (Recommended)

**Heroku (Free tier available):**
```bash
heroku create visual-acuity-upload-server
git add .
git commit -m "Add upload server"
git push heroku main
```

**Railway:**
1. Connect GitHub repo
2. Deploy automatically
3. Set environment variables

**Render:**
1. Connect GitHub repo  
2. Auto-deploy on push
3. Free tier available

## 🔧 Server Features

- **Direct Google Drive upload** to your folder
- **Local backup** of all CSV files
- **Health monitoring** at `/health`
- **File listing** at `/files`
- **Error handling** with detailed logs
- **Automatic retry** logic

## 📊 Monitoring

Check server status:
- Health: `http://your-server/health`
- Files: `http://your-server/files`
- Logs: Server console output

## 🛠️ Troubleshooting

**"credentials.json not found"**
- Download OAuth 2.0 credentials from Google Cloud Console
- Make sure it's named exactly `credentials.json`

**"Permission denied"**
- Ensure Google Drive folder is accessible
- Check OAuth scope includes `drive.file`

**"Connection refused"**
- Make sure server is running
- Check firewall settings
- Verify URL in iOS app matches server address

## 🎉 Success!

Once set up, your data collection workflow becomes:
1. **Tap Data Collection** in iOS app
2. **Complete 25 letters**
3. **CSV automatically appears** in Google Drive
4. **Start analyzing data** immediately!

No more email handling, manual file management, or delays! 🚀
