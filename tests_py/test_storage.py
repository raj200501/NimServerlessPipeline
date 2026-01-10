from __future__ import annotations

import os
import unittest
from tempfile import TemporaryDirectory

from backend_py.config import load_config
from backend_py.storage import write_object


class StorageTests(unittest.TestCase):
    def setUp(self) -> None:
        self._env_backup = dict(os.environ)

    def tearDown(self) -> None:
        os.environ.clear()
        os.environ.update(self._env_backup)

    def test_write_object(self) -> None:
        with TemporaryDirectory() as temp_dir:
            os.environ["NIM_PIPELINE_STORAGE_DIR"] = temp_dir
            cfg = load_config()
            result = write_object(cfg, "example.txt", "hello")
            self.assertTrue(result.path.exists())
            self.assertEqual(result.path.read_text(encoding="utf-8"), "hello")


if __name__ == "__main__":
    unittest.main()
