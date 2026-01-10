# Architecture

This document explains the architecture for NimServerlessPipeline, focusing on the local runtime that makes the README contract deterministic while keeping AWS deployment optional. The local runtime is implemented in Python under `backend_py/`, while the Nim modules in `backend/` provide a Lambda-compatible reference implementation. Both paths share the same data flow: ingest data via HTTP, process and enrich it, persist results to storage, and record metadata in a database-like store.

## Goals

- Provide a fully runnable data pipeline without requiring AWS credentials.
- Keep interfaces compatible with serverless usage (Lambda handler signature, S3/Dynamo shape).
- Offer observable, testable outputs for verification and CI.

## Core Flow

1. **Ingress**: A POST request hits `POST /data` with JSON payload `{ "data": "..." }`.
2. **Validation**: The payload is parsed and validated for size and required fields.
3. **Processing**: The input string is normalized and split into words.
4. **Storage**: The summary string is written to the local storage directory.
5. **Database**: A JSONL record is appended to the local database file.
6. **Response**: A JSON response is returned, providing the summary and record identifier.

This is the same order of operations executed by the Lambda handler for parity with the serverless model.

## Component Diagram (Conceptual)

```
Client -> HTTP Server -> Handler -> Processor -> Storage + Database
```

### HTTP Server

- Python module: `backend_py/server.py`
- Nim module: `backend/http_server.nim` (reference implementation)
- Responsibilities:
  - Accept requests on `/health` and `/data`.
  - Parse JSON and return structured responses.
  - Delegate core business logic to the handler module.

### Handler

- Python module: `backend_py/handler.py`
- Nim module: `backend/handler.nim` (reference implementation)
- Responsibilities:
  - Validate input payloads.
  - Orchestrate processing and persistence.
  - Build a canonical response payload.

### Processor

- Python module: `backend_py/processor.py`
- Nim module: `backend/data_processor.nim` (reference implementation)
- Responsibilities:
  - Normalize input (lowercase, remove punctuation).
  - Compute word counts.
  - Produce a deterministic summary string.

### Storage Backend

- Python module: `backend_py/aws_interaction.py`
- Nim module: `backend/aws_interaction.nim` (reference implementation)
- Local path writes happen via `backend_py/storage.py` or `backend/storage_local.nim`.
- AWS path writes happen via the AWS CLI when `NIM_PIPELINE_MODE=aws`.

### Local Database

- Python module: `backend_py/database.py`
- Nim module: `backend/database_local.nim` (reference implementation)
- Behavior:
  - Append newline-delimited JSON records.
  - Allow simple readback for tests.

### Configuration

- Python module: `backend_py/config.py`
- Nim module: `backend/config.nim` (reference implementation)
- Environment-driven configuration, with defaults for local mode.

## Data Contracts

### Request Payload

```json
{
  "data": "alpha beta alpha"
}
```

### Response Payload

```json
{
  "message": "Processed data: Processed 3 words (2 unique): alpha: 2, beta: 1",
  "recordId": "rec_20240101120000",
  "storageKey": "processed_20240101120000.txt"
}
```

### Stored Object (Local Storage)

- Filename pattern: `processed_YYYYMMDDHHMMSS.txt`
- Contents:
  - The same summary string returned in the HTTP response.

### Stored Record (Local DB)

- JSONL records stored in `local_db/records.jsonl`.
- Example line:

```json
{
  "id": "rec_20240101120000",
  "storedAt": "2024-01-01T12:00:00+00:00",
  "payload": {
    "id": "rec_20240101120000",
    "receivedAt": "2024-01-01T12:00:00+00:00",
    "summary": "Processed 3 words (2 unique): alpha: 2, beta: 1",
    "wordCounts": {
      "alpha": 2,
      "beta": 1
    },
    "totalWords": 3,
    "uniqueWords": 2
  }
}
```

## Error Handling

- Invalid JSON -> `HTTP 400` with `{"error": "Invalid JSON payload"}`.
- Missing `data` field -> `HTTP 400` with `{"error": "Missing 'data' field"}`.
- Empty data -> `HTTP 400` with `{"error": "data must not be empty"}`.
- Payload too large -> `HTTP 400` with `{"error": "data exceeds <bytes>"}`.

## Logging

- Logging is configured in `backend/utils.nim`.
- Default log file: `./logs/pipeline.log`.
- Console logging is also enabled for local debugging.

## Rationale for Local Mode

The repository aims to provide a runnable, deterministic pipeline without requiring AWS credentials or running paid infrastructure. The local mode mirrors the same data flow so that the majority of integration logic can be tested in CI and exercised by users without additional setup.

Key reasons for the local mode:

- **Determinism**: Filesystem state is easy to assert in tests.
- **Accessibility**: Users can run the pipeline without AWS accounts.
- **Parity**: The data contract matches the Lambda handler.

## Extending the Pipeline

### Adding New Processing Steps

1. Add a new transformation function in `backend/data_processor.nim`.
2. Update `renderSummary` to include the new details.
3. Extend `tests/test_data_processor.nim` with additional assertions.

### Adding New Endpoints

1. Update `backend/http_server.nim` to route new endpoints.
2. Reuse handler logic or introduce a new handler module.
3. Add integration tests in `scripts/smoke_test.sh` or new test scripts.

### Adding Structured Outputs

If you want to write JSON objects to storage rather than plain text:

1. Update `backend/storage_local.nim` to call `writeJsonObject`.
2. Update the handler to store the JSON payload.
3. Add tests in `tests/test_storage_local.nim`.

## AWS Deployment Notes

When `NIM_PIPELINE_MODE=aws`:

- `uploadToS3` writes data to the specified bucket using `aws s3 cp`.
- `persistRecord` uses `aws dynamodb put-item` to append records.

AWS deployment is optional and not required for local verification. The repository expects AWS credentials and the AWS CLI to be installed before switching modes.

## File Layout

```
backend/
  aws_interaction.nim   # AWS or local storage operations (Nim reference)
  cli.nim               # CLI entrypoint (Nim reference)
  config.nim            # Environment config (Nim reference)
  data_processor.nim    # Text normalization and counting (Nim reference)
  database_local.nim    # JSONL database writer (Nim reference)
  handler.nim           # Lambda-compatible handler (Nim reference)
  http_server.nim       # HTTP server for local usage (Nim reference)
  storage_local.nim     # Local filesystem storage (Nim reference)
  utils.nim             # Logging setup (Nim reference)
backend_py/
  aws_interaction.py    # AWS or local storage operations (Python runtime)
  cli.py                # CLI entrypoint (Python runtime)
  config.py             # Environment config (Python runtime)
  processor.py          # Text normalization and counting (Python runtime)
  database.py           # JSONL database writer (Python runtime)
  handler.py            # Lambda-compatible handler (Python runtime)
  server.py             # HTTP server for local usage (Python runtime)
  storage.py            # Local filesystem storage (Python runtime)
scripts/
  bootstrap_nim.sh      # Nim installer
  run.sh                # Run local server
  run_tests.sh          # Run tests
  smoke_test.sh         # End-to-end verification
  verify.sh             # CI entrypoint
```

## Observability

The pipeline provides lightweight observability by writing both human-readable summaries and machine-readable records. This is sufficient for local testing and also maps cleanly to production architecture where S3 and DynamoDB provide durable storage.

### Summary Outputs

The summary string is intentionally deterministic:

- Words are normalized to lowercase.
- Punctuation is stripped from both ends of words.
- Word counts are sorted alphabetically to avoid nondeterministic ordering.

### Record Metadata

The record JSON includes:

- `id` : unique identifier generated from the processing timestamp.
- `receivedAt` : ISO-8601 timestamp.
- `summary` : the exact summary string.
- `wordCounts` : a JSON object of word counts.
- `totalWords` : total number of words.
- `uniqueWords` : unique word count.

## Performance Considerations

For local usage, performance is primarily bounded by disk I/O. The pipeline uses simple synchronous writes to ensure correctness in a single-process local environment. If you need to extend to high-throughput workloads:

- Move to asynchronous writes.
- Batch database writes.
- Add a queue or in-memory buffer.

## Security Considerations

Local mode writes to the filesystem only. Ensure that directories referenced by:

- `NIM_PIPELINE_STORAGE_DIR`
- `NIM_PIPELINE_DB_PATH`
- `NIM_PIPELINE_LOG_PATH`

have appropriate permissions. Sensitive data should be handled carefully, especially if you plan to deploy to AWS with real data.

## Known Limits

- Payload size is capped by `NIM_PIPELINE_MAX_PAYLOAD` (default: 1 MB).
- Only a single processing step (word counting) is implemented.
- Local mode does not enforce authentication.

## Future Ideas

- Add authentication middleware for the HTTP server.
- Support JSON payloads with metadata (e.g., customer ID).
- Provide a batch processing endpoint for multi-record ingestion.
- Use structured logging (JSON logs) for better integration with log collectors.
