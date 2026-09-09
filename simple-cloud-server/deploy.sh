#!/bin/bash
# Deployment script for Visual Acuity Test Cloud Upload Server

echo "Setting up the Visual Acuity Test optional upload server."

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
echo "Installing dependencies."
pip install -r requirements_google.txt

# Create necessary directories
mkdir -p uploaded_csvs
mkdir -p logs

echo "Setup complete."
echo ""
echo "Next steps:"
echo "1. For local storage and optional email, run: python app.py"
echo "2. For Google Drive, download credentials.json from Google Cloud Console"
echo "3. Place credentials.json in this directory"
echo "4. Set GOOGLE_DRIVE_FOLDER_ID if the default folder is not appropriate"
echo "5. Run: python google_drive_uploader.py"
echo "6. Set CloudUploadURL in the iOS app only after the endpoint is deployed"
echo ""
echo "Default Google Drive folder: https://drive.google.com/drive/folders/1gQNIG23hqthx7XncvycEDuJPaf8yV012"
echo ""
echo "For production deployment, consider using:"
echo "- Heroku: heroku create your-app-name"
echo "- Railway: railway deploy"
echo "- Render: Connect GitHub repo"
