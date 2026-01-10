from __future__ import annotations

from pathlib import Path
from tempfile import mkdtemp
from typing import Callable


def make_temp_dir(name: str) -> Path:
    path = Path(mkdtemp(prefix=f"nim_pipeline_{name}_"))
    return path


def with_temp_dir(name: str, callback: Callable[[Path], None]) -> None:
    path = make_temp_dir(name)
    callback(path)
