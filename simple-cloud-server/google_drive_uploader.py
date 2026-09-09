#!/usr/bin/env python3
"""
Simple Google Drive Uploader Server
Receives CSV data from iOS app and uploads directly to specified Google Drive folder
"""

from flask import Flask, request, jsonify
import os
import json
import requests
from datetime import datetime
import logging
from pathlib import Path
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import Flow
from google.auth.transport.requests import Request
import pickle

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
GOOGLE_DRIVE_FOLDER_ID = "1gQNIG23hqthx7XncvycEDuJPaf8yV012"  # Your shared folder
UPLOAD_FOLDER = 'uploaded_csvs'
CREDENTIALS_FILE = 'credentials.json'  # Download from Google Cloud Console
TOKEN_FILE = 'token.pickle'

# Google Drive API scopes
SCOPES = ['https://www.googleapis.com/auth/drive.file']

# Create upload directory if it doesn't exist
Path(UPLOAD_FOLDER).mkdir(exist_ok=True)

def get_google_drive_credentials():
    """Get or refresh Google Drive credentials"""
    creds = None
    
    # Load existing token
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, 'rb') as token:
            creds = pickle.load(token)
    
    # If there are no (valid) credentials available, let the user log in
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(CREDENTIALS_FILE):
                raise Exception(f"Please download credentials.json from Google Cloud Console and place it in the server directory")
            
            flow = Flow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
            flow.redirect_uri = 'urn:ietf:wg:oauth:2.0:oob'
            
            auth_url, _ = flow.authorization_url(prompt='consent')
            print(f"Please visit this URL to authorize the application: {auth_url}")
            code = input("Enter the authorization code: ")
            
            flow.fetch_token(code=code)
            creds = flow.credentials
        
        # Save the credentials for the next run
        with open(TOKEN_FILE, 'wb') as token:
            pickle.dump(creds, token)
    
    return creds

def upload_to_google_drive(csv_content: str, filename: str) -> str:
    """Upload CSV content directly to Google Drive folder"""
    try:
        creds = get_google_drive_credentials()
        
        # File metadata
        metadata = {
            'name': filename,
            'parents': [GOOGLE_DRIVE_FOLDER_ID]
        }
        
        # Create multipart upload
        files = {
            'data': ('metadata', json.dumps(metadata), 'application/json; charset=UTF-8'),
            'file': (filename, csv_content, 'text/csv')
        }
        
        headers = {
            'Authorization': f'Bearer {creds.token}'
        }
        
        # Upload to Google Drive
        response = requests.post(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
            headers=headers,
            files=files
        )
        
        if response.status_code == 200:
            file_info = response.json()
            logger.info(f"Successfully uploaded to Google Drive: {file_info.get('id')}")
            return file_info.get('id')
        else:
            logger.error(f"Google Drive upload failed: {response.status_code} - {response.text}")
            raise Exception(f"Google Drive upload failed: {response.status_code}")
            
    except Exception as e:
        logger.error(f"Google Drive upload error: {str(e)}")
        raise

@app.route('/upload', methods=['POST'])
def upload_csv():
    """
    Receive CSV data from iOS app and upload to Google Drive
    """
    try:
        # Validate request
        if not request.is_json:
            return jsonify({'error': 'Content-Type must be application/json'}), 400
        
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['filename', 'content', 'timestamp', 'source']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        filename = data['filename']
        csv_content = data['content']
        timestamp = data['timestamp']
        source = data['source']
        
        logger.info(f"Received upload request: {filename} from {source}")
        
        # Save CSV file locally as backup
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(csv_content)
        
        # Upload to Google Drive
        drive_file_id = upload_to_google_drive(csv_content, filename)
        
        # Create response
        response_data = {
            'status': 'success',
            'message': 'CSV uploaded to Google Drive successfully',
            'filename': filename,
            'google_drive_file_id': drive_file_id,
            'google_drive_folder_url': f"https://drive.google.com/drive/folders/{GOOGLE_DRIVE_FOLDER_ID}",
            'timestamp': datetime.utcnow().isoformat(),
            'local_backup': file_path,
            'lines_processed': len(csv_content.split('\n')) - 1
        }
        
        logger.info(f"Upload completed successfully: {filename} -> Google Drive ID: {drive_file_id}")
        return jsonify(response_data), 200
        
    except Exception as e:
        logger.error(f"Upload failed: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': f'Upload failed: {str(e)}',
            'timestamp': datetime.utcnow().isoformat()
        }), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'google_drive_folder_id': GOOGLE_DRIVE_FOLDER_ID,
        'google_drive_folder_url': f"https://drive.google.com/drive/folders/{GOOGLE_DRIVE_FOLDER_ID}",
        'local_files_count': len(os.listdir(UPLOAD_FOLDER)) if os.path.exists(UPLOAD_FOLDER) else 0
    })

if __name__ == '__main__':
    print(f"Starting server...")
    print(f"Google Drive folder: https://drive.google.com/drive/folders/{GOOGLE_DRIVE_FOLDER_ID}")
    print(f"Upload endpoint: http://localhost:5000/upload")
    app.run(host='0.0.0.0', port=5000, debug=True)
