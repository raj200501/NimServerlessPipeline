#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

export NIM_PIPELINE_MODE=local
export NIM_PIPELINE_PORT=8090
export NIM_PIPELINE_STORAGE_DIR="$ROOT_DIR/local_storage"
export NIM_PIPELINE_DB_PATH="$ROOT_DIR/local_db/records.jsonl"
export NIM_PIPELINE_LOG_PATH="$ROOT_DIR/logs/pipeline.log"

cd "$ROOT_DIR"

python3 -m backend_py.cli server &
SERVER_PID=$!

cleanup() {
  kill "$SERVER_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

sleep 1

curl -sSf http://localhost:8090/health | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert payload["status"]=="ok"; print("health ok")'

curl -sSf -X POST http://localhost:8090/data \
  -H "Content-Type: application/json" \
  -d '{"data":"alpha beta alpha"}' | python3 -c 'import json,sys; payload=json.load(sys.stdin); assert "Processed" in payload["message"]; assert payload["recordId"].startswith("rec_"); print("data ok")'

if ! ls "$ROOT_DIR/local_storage"/processed_*.txt >/dev/null 2>&1; then
  echo "No processed file found"
  exit 1
fi

if [[ ! -f "$ROOT_DIR/local_db/records.jsonl" ]]; then
  echo "No records file found"
  exit 1
fi

echo "Smoke test passed"
