# Local Data Formats

This document describes the on-disk formats used by the local runtime. These formats are intentionally simple to keep the pipeline easy to test and inspect.

## Storage Objects

### Location

Configured by `NIM_PIPELINE_STORAGE_DIR`.

### Naming Scheme

Files are written with the following pattern:

```
processed_YYYYMMDDHHMMSS.txt
```

Example:

```
processed_20240101120000.txt
```

### File Contents

Each file contains the summary string computed by `backend/data_processor.nim`:

```
Processed 3 words (2 unique): alpha: 2, beta: 1
```

### Usage

These files are used by the smoke test to verify that the pipeline wrote an output to disk. They can also be used for manual inspection or future ingestion into other systems.

## Database Records (JSONL)

### Location

Configured by `NIM_PIPELINE_DB_PATH`.

### Format

Each line is a standalone JSON object with the following fields:

- `id`: The record ID generated at processing time.
- `storedAt`: Timestamp of when the record was stored.
- `payload`: A nested JSON object that contains the processing metadata.

Example record:

```json
{"id":"rec_20240101120000","storedAt":"2024-01-01T12:00:00+00:00","payload":{"id":"rec_20240101120000","receivedAt":"2024-01-01T12:00:00+00:00","summary":"Processed 3 words (2 unique): alpha: 2, beta: 1","wordCounts":{"alpha":2,"beta":1},"totalWords":3,"uniqueWords":2}}
```

### Reading Records

To parse the file in Python:

```python
import json

with open("local_db/records.jsonl") as f:
    for line in f:
        record = json.loads(line)
        print(record["payload"]["summary"])
```

### Why JSONL?

JSONL is a natural format for append-only logs:

- Each line is valid JSON.
- Readers can stream records without loading the entire file.
- It works well with command-line tools and log shippers.

## Log File

### Location

Configured by `NIM_PIPELINE_LOG_PATH`.

### Format

The log file uses Nim's logging format (plain text). Example lines:

```
INFO 2024-01-01T12:00:00+00:00 Starting HTTP server on port 8080
INFO 2024-01-01T12:00:05+00:00 Received data (17 bytes)
INFO 2024-01-01T12:00:05+00:00 Stored processed_20240101120005.txt locally at ./local_storage/processed_20240101120005.txt
INFO 2024-01-01T12:00:05+00:00 Persisted record rec_20240101120005 locally at ./local_db/records.jsonl
```

### Rotating Logs

Rotation is not built into the pipeline. If you need rotation:

- Use `logrotate` on Linux.
- Point `NIM_PIPELINE_LOG_PATH` to a directory managed by a log system.

## Compatibility with AWS Mode

When running in AWS mode, the local formats are not used, but the stored data shapes are similar:

- S3 objects contain the same summary string as local storage.
- DynamoDB records contain similar metadata fields.

This compatibility makes it possible to reuse the same processors and integration tests with minimal changes.

## Data Retention

Local mode does not implement retention or cleanup. If you want to keep the workspace clean:

```bash
rm -rf local_storage local_db logs
```

## Data Schema Versioning

Currently there is no explicit schema version. If you make breaking changes:

1. Update the `payload` schema in `backend/handler.nim`.
2. Update this document to reflect the change.
3. Add a note in `docs/ARCHITECTURE.md` describing the migration.

## Example End-to-End Output

Given input:

```
hello hello world
```

The pipeline produces:

- Summary file:
  - `Processed 3 words (2 unique): hello: 2, world: 1`
- JSONL record:

```json
{"id":"rec_20240101120000","storedAt":"2024-01-01T12:00:00+00:00","payload":{"id":"rec_20240101120000","receivedAt":"2024-01-01T12:00:00+00:00","summary":"Processed 3 words (2 unique): hello: 2, world: 1","wordCounts":{"hello":2,"world":1},"totalWords":3,"uniqueWords":2}}
```

## Extending the Formats

If you add new fields (e.g., input length, processing duration):

- Add them in `backend/handler.nim`.
- Update tests to assert on the new fields.
- Update this document to reflect the new schema.

