from __future__ import annotations

import os
import unittest

from backend_py.config import load_config


class ConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self._env_backup = dict(os.environ)

    def tearDown(self) -> None:
        os.environ.clear()
        os.environ.update(self._env_backup)

    def test_defaults(self) -> None:
        os.environ.pop("NIM_PIPELINE_MODE", None)
        os.environ.pop("NIM_PIPELINE_PORT", None)
        cfg = load_config()
        self.assertEqual(cfg.mode, "local")
        self.assertEqual(cfg.port, 8080)

    def test_overrides(self) -> None:
        os.environ["NIM_PIPELINE_MODE"] = "aws"
        os.environ["NIM_PIPELINE_PORT"] = "9090"
        cfg = load_config()
        self.assertEqual(cfg.mode, "aws")
        self.assertEqual(cfg.port, 9090)


if __name__ == "__main__":
    unittest.main()
