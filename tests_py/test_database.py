from __future__ import annotations

import os
import unittest
from tempfile import TemporaryDirectory

from backend_py.config import load_config
from backend_py.database import append_record, read_all_records


class DatabaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self._env_backup = dict(os.environ)

    def tearDown(self) -> None:
        os.environ.clear()
        os.environ.update(self._env_backup)

    def test_append_and_read(self) -> None:
        with TemporaryDirectory() as temp_dir:
            os.environ["NIM_PIPELINE_DB_PATH"] = f"{temp_dir}/records.jsonl"
            cfg = load_config()
            append_record(cfg, "record1", {"value": "one"})
            records = read_all_records(cfg)
            self.assertEqual(len(records), 1)
            self.assertEqual(records[0]["payload"]["value"], "one")


if __name__ == "__main__":
    unittest.main()
