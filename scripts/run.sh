#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

export NIM_PIPELINE_MODE=${NIM_PIPELINE_MODE:-local}
export NIM_PIPELINE_PORT=${NIM_PIPELINE_PORT:-8080}
export NIM_PIPELINE_STORAGE_DIR=${NIM_PIPELINE_STORAGE_DIR:-"$ROOT_DIR/local_storage"}
export NIM_PIPELINE_DB_PATH=${NIM_PIPELINE_DB_PATH:-"$ROOT_DIR/local_db/records.jsonl"}
export NIM_PIPELINE_LOG_PATH=${NIM_PIPELINE_LOG_PATH:-"$ROOT_DIR/logs/pipeline.log"}

cd "$ROOT_DIR"

python3 -m backend_py.cli server
