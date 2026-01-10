from __future__ import annotations

import json
import subprocess
from typing import Dict, Any

from .config import Config
from .storage import write_object
from .database import append_record


def _aws_args(config: Config) -> list[str]:
    args = ["--region", config.aws_region]
    if config.aws_profile:
        args += ["--profile", config.aws_profile]
    return args


def ensure_aws_cli() -> bool:
    try:
        subprocess.run(["aws", "--version"], check=True, capture_output=True)
        return True
    except (OSError, subprocess.CalledProcessError):
        return False


def upload_to_s3(config: Config, key: str, data: str) -> str:
    if config.mode == "aws":
        if not ensure_aws_cli():
            raise OSError("AWS CLI not found. Install awscli or use local mode.")
        tmp_path = write_object(config, key, data).path
        cmd = ["aws", "s3", "cp", str(tmp_path), f"s3://{config.aws_bucket}/{key}"]
        subprocess.run(cmd + _aws_args(config), check=True)
        return f"s3://{config.aws_bucket}/{key}"
    stored = write_object(config, key, data)
    return str(stored.path)


def persist_record(config: Config, record_id: str, payload: Dict[str, Any]) -> str:
    if config.mode == "aws":
        if not ensure_aws_cli():
            raise OSError("AWS CLI not found. Install awscli or use local mode.")
        cmd = [
            "aws",
            "dynamodb",
            "put-item",
            "--table-name",
            "NimTable",
            "--item",
            json.dumps(payload),
        ]
        subprocess.run(cmd + _aws_args(config), check=True)
        return "aws://dynamodb/NimTable"
    record = append_record(config, record_id, payload)
    return str(record.path)
