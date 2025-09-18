#!/bin/bash
# Deployment script for Visual Acuity Test Cloud Upload Server

echo "🚀 Setting up Visual Acuity Test Cloud Upload Server..."

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
echo "📦 Installing dependencies..."
pip install -r requirements_google.txt

# Create necessary directories
mkdir -p uploaded_csvs
mkdir -p logs

echo "✅ Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Download credentials.json from Google Cloud Console"
echo "2. Place credentials.json in this directory"
echo "3. Run: python google_drive_uploader.py"
echo "4. Follow the authorization prompts"
echo "5. Update iOS app cloudUploadURL to your server address"
echo ""
echo "🔗 Your Google Drive folder: https://drive.google.com/drive/folders/1gQNIG23hqthx7XncvycEDuJPaf8yV012"
echo ""
echo "For production deployment, consider using:"
echo "- Heroku: heroku create your-app-name"
echo "- Railway: railway deploy"
echo "- Render: Connect GitHub repo"
