# FAQ

This FAQ addresses common questions about NimServerlessPipeline.

## General

### What is NimServerlessPipeline?

It is a serverless-inspired pipeline with a deterministic local runtime. The local runtime is implemented in Python for zero-install execution, while Nim sources remain for Lambda reference builds.

### Why is there a local mode?

Local mode ensures the project is runnable without AWS credentials and provides deterministic outputs that can be verified in CI. It mirrors the serverless flow for ease of testing.

### Does this project deploy to AWS?

Yes, the repo contains a SAM template under `infrastructure/`, but deployment is optional and not required for local use.

## Installation

### Do I need to install Nim manually?

No. The local runtime uses Python 3. Nim is only required if you want to build the optional Lambda binary.

### Why isn't Nim committed in the repo?

Committing binaries is not allowed. The repo uses a deterministic installer to fetch Nim when needed.

### What platforms are supported?

The scripts are written for Unix-like environments (Linux/macOS). CI uses Ubuntu. Windows users can run the scripts inside WSL.

## Usage

### How do I run the server?

```bash
./scripts/run.sh
```

### How do I send data?

```bash
curl -sSf -X POST http://localhost:8080/data \
  -H "Content-Type: application/json" \
  -d '{"data":"hello world"}'
```

### How do I check the server health?

```bash
curl -sSf http://localhost:8080/health
```

### Where are outputs stored?

- Summary files: `./local_storage`
- JSONL records: `./local_db/records.jsonl`
- Logs: `./logs/pipeline.log`

## Testing

### How do I run tests?

```bash
./scripts/run_tests.sh
```

### How do I run the full verification suite?

```bash
./scripts/verify.sh
```

### What does the smoke test validate?

It validates that the HTTP API responds, processes input, and writes artifacts to disk.

## Configuration

### How do I change the port?

Set `NIM_PIPELINE_PORT`.

### How do I change storage paths?

Set `NIM_PIPELINE_STORAGE_DIR` and `NIM_PIPELINE_DB_PATH`.

### How do I change the payload limit?

Set `NIM_PIPELINE_MAX_PAYLOAD` to the desired byte limit.

## AWS Mode

### How do I enable AWS mode?

```bash
export NIM_PIPELINE_MODE=aws
```

You also need to configure `NIM_PIPELINE_AWS_BUCKET` and AWS credentials.

### Why is AWS CLI required?

The pipeline uses the CLI to interact with S3 and DynamoDB, keeping the implementation minimal and easy to reason about.

## Development

### Where is the main entrypoint?

For local usage, `backend_py/cli.py` is the entrypoint. The Nim Lambda handler is in `backend/handler.nim`.

### How do I add new endpoints?

Update `backend_py/server.py` to route to new handlers, and add tests.

### How do I add new processing logic?

Update `backend_py/processor.py` and extend tests in `tests_py/test_processor.py`.

## Data Formats

### Why JSONL for the database?

JSONL provides an append-only format that mimics DynamoDB records but remains easy to parse with standard tools.

### Can I change the format?

Yes, but you must update the local database module, tests, and documentation.

## CI

### What does CI run?

CI runs `./scripts/verify.sh`, which includes Python unit tests and the smoke test.

### How do I ensure CI passes?

Run `./scripts/verify.sh` locally and ensure it succeeds before pushing.

## Troubleshooting

### The server doesn't start. What should I check?

- Is the port already in use?
- Are the directories writable?
- Is Python 3 available?

### The smoke test fails. What should I check?

- Ensure `curl` and `python3` are installed.
- Ensure port 8090 is free.
- Check `./logs/pipeline.log` for errors.

## Contribution

### What style guidelines should I follow?

- Keep outputs deterministic.
- Avoid external dependencies unless necessary.
- Update docs and tests when behavior changes.

### How do I propose changes?

1. Create a branch.
2. Make updates and run `./scripts/verify.sh`.
3. Submit a PR with a summary and test results.

## Glossary

- **Pipeline**: The end-to-end flow from ingestion to storage.
- **Local mode**: Running without AWS services, using local files.
- **AWS mode**: Running with AWS CLI to store outputs in S3 and DynamoDB.
- **JSONL**: JSON Lines format (one JSON object per line).

