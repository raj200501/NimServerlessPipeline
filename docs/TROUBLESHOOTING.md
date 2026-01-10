# Troubleshooting

This document lists common issues and fixes for NimServerlessPipeline.

## Common Errors

### `Permission denied` when running scripts

Cause: Shell scripts are not executable.

Fix:

```bash
chmod +x scripts/*.sh backend/build.sh infrastructure/deploy.sh
```

### `python3: command not found`

Cause: Python 3 is not installed or not on `PATH`.

Fix:

Install Python 3 and rerun `./scripts/run.sh`.

### `Nim not found` (optional)

Cause: Nim is not installed or not on `PATH` when attempting the optional Lambda build.

Fix:

```bash
./scripts/bootstrap_nim.sh
```

### `curl: (7) Failed to connect`

Cause: HTTP server is not running or is listening on a different port.

Fix:

- Confirm server is running: `ps -ef | grep backend_py`.
- Ensure `NIM_PIPELINE_PORT` matches your curl command.

### `Request body is required`

Cause: You called `/data` without sending JSON.

Fix:

```bash
curl -sSf -X POST http://localhost:8080/data \
  -H "Content-Type: application/json" \
  -d '{"data":"hello"}'
```

### `Invalid JSON payload`

Cause: The payload is not valid JSON.

Fix:

Ensure the payload is a JSON object with double quotes.

### `data must not be empty`

Cause: The `data` field is blank or whitespace.

Fix:

Send a non-empty string.

### `data exceeds 1048576 bytes`

Cause: Payload is larger than the maximum configured size.

Fix:

Increase `NIM_PIPELINE_MAX_PAYLOAD` or send smaller payloads.

### Logs not created

Cause: The log directory is not writable.

Fix:

Set `NIM_PIPELINE_LOG_PATH` to a writable location.

### Local storage files not found

Cause: The pipeline failed before writing or you are looking in the wrong directory.

Fix:

- Check `NIM_PIPELINE_STORAGE_DIR`.
- Look at the logs in `./logs/pipeline.log`.

## AWS Mode Issues

### `AWS CLI not found`

Cause: The AWS CLI is not installed.

Fix:

Install it using your package manager or from AWS documentation.

### `AccessDenied` when uploading to S3

Cause: IAM permissions are missing.

Fix:

Ensure your IAM role/user has `s3:PutObject` permissions for the bucket.

### `ResourceNotFoundException` for DynamoDB

Cause: The DynamoDB table does not exist in the region.

Fix:

Ensure the SAM stack has been deployed and the table name matches `NimTable`.

### `sam` command not found

Cause: AWS SAM CLI not installed.

Fix:

Install the SAM CLI and retry `./infrastructure/deploy.sh`.

## CI Issues

### Verification fails in GitHub Actions

Cause: The verification command did not succeed locally.

Fix:

Run:

```bash
./scripts/verify.sh
```

Then inspect the logs or output for the failing step.

## Debugging Tips

- Use `NIM_PIPELINE_LOG_PATH` to capture logs in a known location.
- Check Python stack traces in the terminal for runtime errors.
- For AWS mode, use `aws s3 ls` to confirm connectivity.

## FAQ

### Can I change the port without updating README?

Yes. The README uses port 8080 by default, but you can override `NIM_PIPELINE_PORT`.

### Can I run multiple servers simultaneously?

Yes, as long as each uses a different port and different storage directories.

### Why JSONL for local database?

JSONL is simple, append-only, and easy to parse for tests. It mirrors the concept of writing records to DynamoDB without requiring a database engine.

