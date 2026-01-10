#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

"$ROOT_DIR/scripts/bootstrap_nim.sh"

cd "$ROOT_DIR/backend"

nim c -d:release --threads:on --out:handler handler.nim

if command -v zip >/dev/null 2>&1; then
  zip -j lambda.zip handler
else
  echo "zip not found; skipping lambda.zip creation"
fi
