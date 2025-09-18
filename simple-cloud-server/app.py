#!/usr/bin/env python3
"""
Simple Cloud Upload Server for Visual Acuity Test Data Collection
Receives CSV data from iOS app and saves to local storage + emails results
"""

from flask import Flask, request, jsonify
import os
import json
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from datetime import datetime
import logging
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
UPLOAD_FOLDER = 'uploaded_csvs'
EMAIL_CONFIG = {
    'smtp_server': 'smtp.gmail.com',  # Change for your email provider
    'smtp_port': 587,
    'sender_email': 'your-email@gmail.com',  # Replace with your email
    'sender_password': 'your-app-password',   # Replace with app password
    'recipient_email': 'mabdel03@mit.edu'
}

# Create upload directory if it doesn't exist
Path(UPLOAD_FOLDER).mkdir(exist_ok=True)

@app.route('/upload', methods=['POST'])
def upload_csv():
    """
    Receive CSV data from iOS app and process it
    Expected JSON payload:
    {
        "filename": "2024-01-15-143022.csv",
        "content": "Letter_Displayed,Transcribed_Text,Mapped_Result\nC,see,C\n...",
        "timestamp": "2024-01-15T14:30:22Z",
        "source": "visual_acuity_ios_app",
        "email_recipient": "mabdel03@mit.edu"
    }
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
        email_recipient = data.get('email_recipient', EMAIL_CONFIG['recipient_email'])
        
        logger.info(f"Received upload request: {filename} from {source}")
        
        # Save CSV file locally
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(csv_content)
        
        logger.info(f"Saved CSV file: {file_path}")
        
        # Send email with CSV attachment
        email_sent = send_email_with_csv(
            csv_content=csv_content,
            filename=filename,
            recipient=email_recipient,
            timestamp=timestamp
        )
        
        # Create response
        response_data = {
            'status': 'success',
            'message': 'CSV uploaded and processed successfully',
            'filename': filename,
            'timestamp': datetime.utcnow().isoformat(),
            'file_path': file_path,
            'email_sent': email_sent,
            'lines_processed': len(csv_content.split('\n')) - 1  # Subtract header
        }
        
        logger.info(f"Upload completed successfully: {filename}")
        return jsonify(response_data), 200
        
    except Exception as e:
        logger.error(f"Upload failed: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': f'Upload failed: {str(e)}',
            'timestamp': datetime.utcnow().isoformat()
        }), 500

def send_email_with_csv(csv_content: str, filename: str, recipient: str, timestamp: str) -> bool:
    """
    Send email with CSV attachment
    """
    try:
        # Create message
        msg = MIMEMultipart()
        msg['From'] = EMAIL_CONFIG['sender_email']
        msg['To'] = recipient
        msg['Subject'] = f"{filename} Data Collection - Cloud Upload"
        
        # Email body
        body = f"""
Data collection completed and uploaded to cloud server.

File: {filename}
Upload Time: {timestamp}
Source: Visual Acuity Test iOS App
Lines: {len(csv_content.split('\n')) - 1} data points

The CSV file is attached and also stored on the cloud server for backup.

Best regards,
Visual Acuity Test Cloud Server
"""
        
        msg.attach(MIMEText(body, 'plain'))
        
        # Attach CSV file
        attachment = MIMEBase('application', 'octet-stream')
        attachment.set_payload(csv_content.encode('utf-8'))
        encoders.encode_base64(attachment)
        attachment.add_header(
            'Content-Disposition',
            f'attachment; filename= {filename}'
        )
        msg.attach(attachment)
        
        # Send email
        server = smtplib.SMTP(EMAIL_CONFIG['smtp_server'], EMAIL_CONFIG['smtp_port'])
        server.starttls()
        server.login(EMAIL_CONFIG['sender_email'], EMAIL_CONFIG['sender_password'])
        text = msg.as_string()
        server.sendmail(EMAIL_CONFIG['sender_email'], recipient, text)
        server.quit()
        
        logger.info(f"Email sent successfully to {recipient}")
        return True
        
    except Exception as e:
        logger.error(f"Email sending failed: {str(e)}")
        return False

@app.route('/health', methods=['GET'])
def health_check():
    """
    Health check endpoint
    """
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'upload_folder': UPLOAD_FOLDER,
        'files_count': len(os.listdir(UPLOAD_FOLDER)) if os.path.exists(UPLOAD_FOLDER) else 0
    })

@app.route('/files', methods=['GET'])
def list_files():
    """
    List uploaded files (for debugging/monitoring)
    """
    try:
        files = []
        if os.path.exists(UPLOAD_FOLDER):
            for filename in os.listdir(UPLOAD_FOLDER):
                if filename.endswith('.csv'):
                    file_path = os.path.join(UPLOAD_FOLDER, filename)
                    stat = os.stat(file_path)
                    files.append({
                        'filename': filename,
                        'size_bytes': stat.st_size,
                        'created_at': datetime.fromtimestamp(stat.st_ctime).isoformat(),
                        'modified_at': datetime.fromtimestamp(stat.st_mtime).isoformat()
                    })
        
        return jsonify({
            'status': 'success',
            'files_count': len(files),
            'files': sorted(files, key=lambda x: x['created_at'], reverse=True)
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/', methods=['GET'])
def index():
    """
    Simple status page
    """
    return """
    <h1>Visual Acuity Test Cloud Upload Server</h1>
    <p>Server is running and ready to receive CSV uploads.</p>
    <ul>
        <li><a href="/health">Health Check</a></li>
        <li><a href="/files">List Files</a></li>
    </ul>
    <p>Upload endpoint: POST /upload</p>
    """

if __name__ == '__main__':
    # For development - use a production WSGI server for deployment
    app.run(host='0.0.0.0', port=5000, debug=True)
