from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Config:
    mode: str
    port: int
    storage_dir: Path
    database_path: Path
    log_path: Path
    max_payload_bytes: int
    aws_bucket: str
    aws_region: str
    aws_profile: str | None


DEFAULT_PORT = 8080
DEFAULT_MAX_PAYLOAD = 1024 * 1024
DEFAULT_STORAGE_DIR = Path("./local_storage")
DEFAULT_DATABASE_PATH = Path("./local_db/records.jsonl")
DEFAULT_LOG_PATH = Path("./logs/pipeline.log")
DEFAULT_BUCKET = "nim-local-bucket"
DEFAULT_REGION = "us-east-1"


def _get_env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def load_config() -> Config:
    mode = os.getenv("NIM_PIPELINE_MODE", "local").lower()
    return Config(
        mode=mode,
        port=_get_env_int("NIM_PIPELINE_PORT", DEFAULT_PORT),
        storage_dir=Path(os.getenv("NIM_PIPELINE_STORAGE_DIR", str(DEFAULT_STORAGE_DIR))),
        database_path=Path(os.getenv("NIM_PIPELINE_DB_PATH", str(DEFAULT_DATABASE_PATH))),
        log_path=Path(os.getenv("NIM_PIPELINE_LOG_PATH", str(DEFAULT_LOG_PATH))),
        max_payload_bytes=_get_env_int("NIM_PIPELINE_MAX_PAYLOAD", DEFAULT_MAX_PAYLOAD),
        aws_bucket=os.getenv("NIM_PIPELINE_AWS_BUCKET", DEFAULT_BUCKET),
        aws_region=os.getenv("NIM_PIPELINE_AWS_REGION", DEFAULT_REGION),
        aws_profile=os.getenv("NIM_PIPELINE_AWS_PROFILE") or None,
    )


def ensure_directories(config: Config) -> None:
    config.storage_dir.mkdir(parents=True, exist_ok=True)
    config.database_path.parent.mkdir(parents=True, exist_ok=True)
    config.log_path.parent.mkdir(parents=True, exist_ok=True)
    config.log_path.touch(exist_ok=True)


def describe(config: Config) -> str:
    return (
        f"mode={config.mode} port={config.port} storageDir={config.storage_dir} "
        f"dbPath={config.database_path} logPath={config.log_path} "
        f"maxPayload={config.max_payload_bytes}"
    )
