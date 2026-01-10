# Configuration Reference

This document describes configuration options for NimServerlessPipeline. Configuration is driven by environment variables. Defaults are designed for local execution.

## Quick Reference Table

| Variable | Default | Description |
| --- | --- | --- |
| `NIM_PIPELINE_MODE` | `local` | Execution mode: `local` or `aws`. |
| `NIM_PIPELINE_PORT` | `8080` | HTTP server port. |
| `NIM_PIPELINE_STORAGE_DIR` | `./local_storage` | Directory to store processed outputs in local mode. |
| `NIM_PIPELINE_DB_PATH` | `./local_db/records.jsonl` | Path to JSONL database file for local mode. |
| `NIM_PIPELINE_LOG_PATH` | `./logs/pipeline.log` | File path for pipeline logs. |
| `NIM_PIPELINE_MAX_PAYLOAD` | `1048576` | Maximum payload size in bytes. |
| `NIM_PIPELINE_AWS_BUCKET` | `nim-local-bucket` | AWS S3 bucket name when in `aws` mode. |
| `NIM_PIPELINE_AWS_REGION` | `us-east-1` | AWS region used by the CLI when in `aws` mode. |
| `NIM_PIPELINE_AWS_PROFILE` | _empty_ | AWS CLI profile name. Optional. |

## Local Mode

Local mode is the default behavior. It does not require AWS credentials. It stores outputs and metadata to the filesystem so that the pipeline can be tested deterministically.

### Example Local Configuration

```bash
export NIM_PIPELINE_MODE=local
export NIM_PIPELINE_PORT=8080
export NIM_PIPELINE_STORAGE_DIR=./local_storage
export NIM_PIPELINE_DB_PATH=./local_db/records.jsonl
export NIM_PIPELINE_LOG_PATH=./logs/pipeline.log
```

### Local Storage Directory

The storage directory is used to write the processed summary strings. Each record is stored with the pattern:

```
processed_YYYYMMDDHHMMSS.txt
```

The contents of each file match the `message` value from the HTTP response, which is intentionally deterministic and easy to validate in tests.

### Local Database File

The database file is JSONL (JSON Lines). Each line contains one record. This design allows the file to be appended with constant time writes.

Example contents:

```json
{"id":"rec_20240101120000","storedAt":"2024-01-01T12:00:00+00:00","payload":{"id":"rec_20240101120000","receivedAt":"2024-01-01T12:00:00+00:00","summary":"Processed 3 words (2 unique): alpha: 2, beta: 1","wordCounts":{"alpha":2,"beta":1},"totalWords":3,"uniqueWords":2}}
```

### Logging

Logging is written to both the console and a log file. Ensure the directory for `NIM_PIPELINE_LOG_PATH` exists or is creatable.

## AWS Mode

AWS mode is optional. It is provided for parity with the original serverless intention. When enabled, the handler calls out to the AWS CLI.

### Required Tools

- AWS CLI installed and available on `PATH`.
- AWS credentials configured (via `aws configure`, environment variables, or a profile).

### Required AWS Resources

The infrastructure template (`infrastructure/template.yaml`) creates:

- An S3 bucket for object storage.
- A DynamoDB table for metadata.
- An API Gateway / Lambda integration.

### Example AWS Configuration

```bash
export NIM_PIPELINE_MODE=aws
export NIM_PIPELINE_AWS_BUCKET=my-bucket
export NIM_PIPELINE_AWS_REGION=us-east-1
export NIM_PIPELINE_AWS_PROFILE=default
```

### Behavior in AWS Mode

- `uploadToS3` runs: `aws s3 cp <file> s3://<bucket>/<key>`.
- `persistRecord` runs: `aws dynamodb put-item --table-name NimTable --item <json>`.

### Limits and Assumptions

- The AWS CLI must be configured for the specified region.
- The DynamoDB table name is `NimTable` by default, matching the template.
- The IAM user/role must have permissions for S3 and DynamoDB.

## Payload Limits

The maximum payload size is enforced in the handler. If `data` is larger than `NIM_PIPELINE_MAX_PAYLOAD`, the handler returns an HTTP 400 error with a descriptive message.

Default payload limit is 1 MB, which is appropriate for small text data. Adjust this value based on your needs and the memory constraints of your runtime.

## Environment File

A `.env.example` file is provided so you can copy and customize it. The `scripts/run.sh` script uses defaults if values are not set.

Example:

```bash
cp .env.example .env
```

Then update `.env` to point to your preferred directories and port.

## Configuration Tips

- Use absolute paths if you plan to run the server from different working directories.
- Avoid placing the database file in a directory that is cleaned by automation.
- When running in CI, use workspace-relative paths to keep artifacts within the job workspace.

## Troubleshooting Configuration

If the server fails to start:

1. Ensure `NIM_PIPELINE_PORT` is not already in use.
2. Confirm that `NIM_PIPELINE_STORAGE_DIR`, `NIM_PIPELINE_DB_PATH`, and `NIM_PIPELINE_LOG_PATH` are writable.
3. Verify your `.env` file is loaded (if you rely on it).

## Configuration FAQs

### Why not use a config file instead of env variables?

The pipeline aims to mimic AWS Lambda behavior, which primarily relies on environment variables. It keeps configuration consistent between local and deployed environments.

### Can I use a custom DynamoDB table name?

Currently the table name is fixed to `NimTable` for AWS mode. If you need configurability, update `backend/aws_interaction.nim` and `infrastructure/template.yaml` in tandem, then add tests to confirm the new behavior.

### Can I disable logging?

Logging can be disabled by removing or adjusting the handlers in `backend/utils.nim`. Local debugging is easier with logs enabled, so logging is on by default.

## Configuration Checklist

Use this checklist before running the pipeline:

- [ ] `NIM_PIPELINE_MODE` set to `local` for local runs.
- [ ] `NIM_PIPELINE_PORT` is free.
- [ ] `NIM_PIPELINE_STORAGE_DIR` exists or is creatable.
- [ ] `NIM_PIPELINE_DB_PATH` points to a file within a writable directory.
- [ ] `NIM_PIPELINE_LOG_PATH` points to a file within a writable directory.

For AWS mode:

- [ ] AWS CLI installed and on `PATH`.
- [ ] AWS credentials configured.
- [ ] `NIM_PIPELINE_AWS_BUCKET` set to a bucket you control.
- [ ] `NIM_PIPELINE_AWS_REGION` set to the target region.

