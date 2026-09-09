import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import app as upload_app


class UploadServerTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        upload_app.UPLOAD_FOLDER = Path(self.temp_dir.name)
        upload_app.UPLOAD_FOLDER.mkdir(parents=True, exist_ok=True)
        self.original_email_enabled = upload_app.EMAIL_ENABLED
        upload_app.EMAIL_ENABLED = False
        self.client = upload_app.app.test_client()

    def tearDown(self):
        upload_app.EMAIL_ENABLED = self.original_email_enabled
        self.temp_dir.cleanup()

    def test_health_endpoint(self):
        response = self.client.get("/health")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["status"], "healthy")

    def test_upload_rejects_non_json(self):
        response = self.client.post("/upload", data="not json")

        self.assertEqual(response.status_code, 400)
        self.assertIn("Content-Type", response.get_json()["error"])

    def test_upload_rejects_missing_required_field(self):
        response = self.client.post("/upload", json={"filename": "data.csv"})

        self.assertEqual(response.status_code, 400)
        self.assertIn("Missing required field", response.get_json()["error"])

    def test_upload_rejects_filename_traversal(self):
        payload = {
            "filename": "../data.csv",
            "content": "a,b\n1,2\n",
            "timestamp": "2026-07-08T00:00:00Z",
            "source": "unit_test",
        }

        response = self.client.post("/upload", json=payload)

        self.assertEqual(response.status_code, 400)
        self.assertIn("path components", response.get_json()["message"])

    def test_successful_csv_upload_with_email_mocked(self):
        payload = {
            "filename": "data.csv",
            "content": "a,b\n1,2\n3,4\n",
            "timestamp": "2026-07-08T00:00:00Z",
            "source": "unit_test",
        }

        upload_app.EMAIL_ENABLED = True
        with patch.object(upload_app, "send_email_with_csv", return_value=True) as send_email:
            response = self.client.post("/upload", json=payload)

        body = response.get_json()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(body["lines_processed"], 2)
        self.assertTrue(body["email_sent"])
        self.assertTrue((upload_app.UPLOAD_FOLDER / "data.csv").exists())
        send_email.assert_called_once()


if __name__ == "__main__":
    unittest.main()
