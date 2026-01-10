from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Dict, Any

from .config import Config


@dataclass
class StoredRecord:
    record_id: str
    path: Path
    stored_at: datetime


def append_record(config: Config, record_id: str, payload: Dict[str, Any]) -> StoredRecord:
    config.database_path.parent.mkdir(parents=True, exist_ok=True)
    record = {
        "id": record_id,
        "storedAt": datetime.now(timezone.utc).isoformat(),
        "payload": payload,
    }
    with config.database_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record) + "\n")
    return StoredRecord(
        record_id=record_id,
        path=config.database_path,
        stored_at=datetime.now(timezone.utc),
    )


def read_all_records(config: Config) -> List[Dict[str, Any]]:
    if not config.database_path.exists():
        return []
    records: List[Dict[str, Any]] = []
    with config.database_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            records.append(json.loads(line))
    return records
