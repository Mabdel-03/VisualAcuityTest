#!/usr/bin/env python3
"""
CSV upload server for Visual Acuity Test data collection.

The server accepts JSON payloads from the iOS application, stores validated CSV
content locally, and optionally emails the CSV to a configured recipient.
"""

from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
from dotenv import load_dotenv
from pathlib import Path
from io import StringIO
import csv
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from datetime import datetime
import logging


load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
UPLOAD_FOLDER = Path(os.getenv('UPLOAD_FOLDER', 'uploaded_csvs'))
MAX_FILE_SIZE_BYTES = int(os.getenv('MAX_FILE_SIZE_MB', '10')) * 1024 * 1024
EMAIL_ENABLED = os.getenv('EMAIL_ENABLED', 'false').lower() in {'1', 'true', 'yes', 'on'}
EMAIL_CONFIG = {
    'smtp_server': os.getenv('SMTP_SERVER', 'smtp.gmail.com'),
    'smtp_port': int(os.getenv('SMTP_PORT', '587')),
    'sender_email': os.getenv('SENDER_EMAIL', ''),
    'sender_password': os.getenv('SENDER_PASSWORD', ''),
    'recipient_email': os.getenv('RECIPIENT_EMAIL', 'mabdel03@mit.edu')
}

# Create upload directory if it doesn't exist
UPLOAD_FOLDER.mkdir(parents=True, exist_ok=True)


def count_csv_data_rows(csv_content: str) -> int:
    """Return the number of non-empty CSV data rows after the header."""
    rows = list(csv.reader(StringIO(csv_content)))
    non_empty_rows = [row for row in rows if any(cell.strip() for cell in row)]
    if len(non_empty_rows) <= 1:
        return 0
    return len(non_empty_rows) - 1


def sanitize_csv_filename(filename: str) -> str:
    """Validate and sanitize a client-provided CSV filename."""
    if not isinstance(filename, str):
        raise ValueError('filename must be a string')

    raw_filename = filename.strip()
    if not raw_filename:
        raise ValueError('filename must not be empty')
    if raw_filename != Path(raw_filename).name or '/' in raw_filename or '\\' in raw_filename:
        raise ValueError('filename must not contain path components')

    safe_filename = secure_filename(raw_filename)
    if not safe_filename:
        raise ValueError('filename contains no valid characters')
    if not safe_filename.lower().endswith('.csv'):
        raise ValueError('filename must use the .csv extension')

    return safe_filename


def validate_csv_content(csv_content: str) -> int:
    """Validate uploaded CSV content and return its data row count."""
    if not isinstance(csv_content, str):
        raise ValueError('content must be a string')
    if not csv_content.strip():
        raise ValueError('content must not be empty')
    if len(csv_content.encode('utf-8')) > MAX_FILE_SIZE_BYTES:
        raise ValueError('content exceeds configured size limit')

    try:
        rows = list(csv.reader(StringIO(csv_content)))
    except csv.Error as exc:
        raise ValueError(f'content is not valid CSV: {exc}') from exc

    non_empty_rows = [row for row in rows if any(cell.strip() for cell in row)]
    if not non_empty_rows:
        raise ValueError('content must include a CSV header')
    if not any(cell.strip() for cell in non_empty_rows[0]):
        raise ValueError('CSV header must include at least one field')

    return max(len(non_empty_rows) - 1, 0)

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
        
        data = request.get_json(silent=True)
        if not isinstance(data, dict):
            return jsonify({'error': 'Request body must be a JSON object'}), 400
        
        # Validate required fields
        required_fields = ['filename', 'content', 'timestamp', 'source']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        filename = sanitize_csv_filename(data['filename'])
        csv_content = data['content']
        timestamp = data['timestamp']
        source = data['source']
        lines_processed = validate_csv_content(csv_content)
        email_recipient = data.get('email_recipient', EMAIL_CONFIG['recipient_email'])
        
        logger.info(f"Received upload request: {filename} from {source}")
        
        # Save CSV file locally
        file_path = UPLOAD_FOLDER / filename
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(csv_content)
        
        logger.info(f"Saved CSV file: {file_path}")
        
        # Send email with CSV attachment
        email_sent = False
        if EMAIL_ENABLED:
            email_sent = send_email_with_csv(
                csv_content=csv_content,
                filename=filename,
                recipient=email_recipient,
                timestamp=timestamp,
                lines_processed=lines_processed
            )
        
        # Create response
        response_data = {
            'status': 'success',
            'message': 'CSV uploaded and processed successfully',
            'filename': filename,
            'timestamp': datetime.utcnow().isoformat(),
            'file_path': str(file_path),
            'email_sent': email_sent,
            'lines_processed': lines_processed
        }
        
        logger.info(f"Upload completed successfully: {filename}")
        return jsonify(response_data), 200
    except ValueError as e:
        logger.warning(f"Upload validation failed: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }), 400
        
    except Exception as e:
        logger.error(f"Upload failed: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': f'Upload failed: {str(e)}',
            'timestamp': datetime.utcnow().isoformat()
        }), 500

def send_email_with_csv(
    csv_content: str,
    filename: str,
    recipient: str,
    timestamp: str,
    lines_processed: int | None = None
) -> bool:
    """
    Send email with CSV attachment
    """
    try:
        if not EMAIL_CONFIG['sender_email'] or not EMAIL_CONFIG['sender_password']:
            logger.warning("Email is enabled but sender credentials are incomplete")
            return False

        if lines_processed is None:
            lines_processed = count_csv_data_rows(csv_content)

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
Lines: {lines_processed} data points

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
        'upload_folder': str(UPLOAD_FOLDER),
        'email_enabled': EMAIL_ENABLED,
        'files_count': len(list(UPLOAD_FOLDER.glob('*.csv'))) if UPLOAD_FOLDER.exists() else 0
    })

@app.route('/files', methods=['GET'])
def list_files():
    """
    List uploaded files (for debugging/monitoring)
    """
    try:
        files = []
        if UPLOAD_FOLDER.exists():
            for file_path in UPLOAD_FOLDER.glob('*.csv'):
                stat = file_path.stat()
                files.append({
                    'filename': file_path.name,
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
    host = os.getenv('HOST', '0.0.0.0')
    port = int(os.getenv('PORT', '5000'))
    debug = os.getenv('DEBUG', 'false').lower() in {'1', 'true', 'yes', 'on'}
    app.run(host=host, port=port, debug=debug)
