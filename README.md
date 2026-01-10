# NimServerlessPipeline

**NimServerlessPipeline** is a serverless-inspired data processing pipeline with a deterministic local runtime. The local runtime is implemented in Python (for zero-install, CI-friendly execution) and mirrors the Nim-based Lambda handler included in `backend/`. The pipeline processes text payloads, writes deterministic summaries to storage, and records metadata in a JSONL database file.

## Features

- Local HTTP service with `/health` and `/data` endpoints (Python runtime).
- Deterministic text processing with word counts.
- Local storage and JSONL database outputs for easy verification.
- Optional Nim Lambda build (requires Nim toolchain).
- Optional AWS S3/DynamoDB integration via AWS CLI.
- Comprehensive unit tests and a deterministic smoke test.

## Repository Layout

```
backend/           # Nim source code (Lambda handler)
backend_py/        # Python runtime used for local execution
infrastructure/    # AWS SAM template (optional)
scripts/           # Local dev and verification scripts
tests/             # Nim unit tests (optional)
tests_py/          # Python unit tests (canonical)
```

## Installation

Clone the repository:

```bash
git clone https://github.com/your-username/NimServerlessPipeline.git
cd NimServerlessPipeline
```

The local runtime uses Python 3 (no extra dependencies). The Nim toolchain is only required if you want to build the Lambda binary.

## Verified Quickstart (Local)

> These commands were executed successfully.

```bash
./scripts/run.sh
```

In another terminal:

```bash
curl -sSf http://localhost:8080/health
curl -sSf -X POST http://localhost:8080/data \
  -H "Content-Type: application/json" \
  -d '{"data":"alpha beta alpha"}'
```

Expected behavior:

- `/health` returns `{"status":"ok","mode":"local"}`.
- `/data` returns a JSON payload containing `message`, `recordId`, and `storageKey`.
- A summary file appears under `./local_storage`.
- A JSONL record appears under `./local_db/records.jsonl`.

## Verified Verification (CI + Local)

```bash
./scripts/verify.sh
```

This command runs Python unit tests and an end-to-end smoke test against the local HTTP server.

## Optional Nim Build (Lambda)

If you need the Nim Lambda binary:

```bash
./backend/build.sh
```

This uses `scripts/bootstrap_nim.sh` to install Nim via `choosenim` when possible.

## Configuration

Environment variables control the runtime. Defaults are tuned for local execution. See `.env.example` and `docs/CONFIGURATION.md` for details.

Common local overrides:

```bash
export NIM_PIPELINE_MODE=local
export NIM_PIPELINE_PORT=8080
export NIM_PIPELINE_STORAGE_DIR=./local_storage
export NIM_PIPELINE_DB_PATH=./local_db/records.jsonl
export NIM_PIPELINE_LOG_PATH=./logs/pipeline.log
```

## AWS Deployment (Optional)

The repository contains a SAM template under `infrastructure/`. AWS deployment requires the AWS CLI and SAM CLI. This is **optional** and not required for local verification.

```bash
export AWS_S3_BUCKET=your-bucket
cd infrastructure
./deploy.sh
```

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Configuration](docs/CONFIGURATION.md)
- [API Reference](docs/API.md)
- [Testing Guide](docs/TESTING.md)
- [Development Guide](docs/DEVELOPMENT.md)
- [Local Data Formats](docs/LOCAL_DATA_FORMATS.md)
- [Module Reference](docs/MODULE_REFERENCE.md)
- [CI Notes](docs/CI.md)
- [Operations Runbook](docs/OPERATIONS.md)
- [FAQ](docs/FAQ.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
