from __future__ import annotations

import os
import unittest
from tempfile import TemporaryDirectory

from backend_py.handler import handler


class HandlerTests(unittest.TestCase):
    def setUp(self) -> None:
        self._env_backup = dict(os.environ)

    def tearDown(self) -> None:
        os.environ.clear()
        os.environ.update(self._env_backup)

    def test_handler_success(self) -> None:
        with TemporaryDirectory() as temp_dir:
            os.environ["NIM_PIPELINE_MODE"] = "local"
            os.environ["NIM_PIPELINE_STORAGE_DIR"] = f"{temp_dir}/storage"
            os.environ["NIM_PIPELINE_DB_PATH"] = f"{temp_dir}/records.jsonl"
            response = handler({"data": "sample data"}, {})
            self.assertEqual(response["statusCode"], 200)
            self.assertIn("Processed", response["body"]["message"])

    def test_handler_missing_data(self) -> None:
        response = handler({}, {})
        self.assertEqual(response["statusCode"], 400)
        self.assertIn("Missing", response["body"]["error"])


if __name__ == "__main__":
    unittest.main()
