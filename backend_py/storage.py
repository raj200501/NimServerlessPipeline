from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from .config import Config


@dataclass
class StoredObject:
    key: str
    path: Path
    size_bytes: int
    stored_at: datetime


def storage_path(config: Config, key: str) -> Path:
    safe_key = key.replace("/", "_")
    config.storage_dir.mkdir(parents=True, exist_ok=True)
    return config.storage_dir / safe_key


def write_object(config: Config, key: str, data: str) -> StoredObject:
    path = storage_path(config, key)
    path.write_text(data, encoding="utf-8")
    return StoredObject(
        key=key,
        path=path,
        size_bytes=len(data),
        stored_at=datetime.now(timezone.utc),
    )
