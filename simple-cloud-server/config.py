"""
Configuration for the Visual Acuity Test Cloud Upload Server
"""
import os
from dotenv import load_dotenv

load_dotenv()

# Email configuration
EMAIL_CONFIG = {
    'smtp_server': os.getenv('SMTP_SERVER', 'smtp.gmail.com'),
    'smtp_port': int(os.getenv('SMTP_PORT', '587')),
    'sender_email': os.getenv('SENDER_EMAIL', 'your-email@gmail.com'),
    'sender_password': os.getenv('SENDER_PASSWORD', 'your-app-password'),
    'recipient_email': os.getenv('RECIPIENT_EMAIL', 'mabdel03@mit.edu')
}

# Server configuration
SERVER_CONFIG = {
    'host': os.getenv('HOST', '0.0.0.0'),
    'port': int(os.getenv('PORT', '5000')),
    'debug': os.getenv('DEBUG', 'False').lower() == 'true'
}

# Storage configuration
STORAGE_CONFIG = {
    'upload_folder': os.getenv('UPLOAD_FOLDER', 'uploaded_csvs'),
    'max_file_size_mb': int(os.getenv('MAX_FILE_SIZE_MB', '10'))
}
