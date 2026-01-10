# Operations Runbook

This runbook describes how to operate NimServerlessPipeline in local mode and provides optional guidance for AWS mode. It is aimed at maintainers and release engineers who need deterministic, repeatable procedures.

## Table of Contents

- [Service Overview](#service-overview)
- [Startup Procedure](#startup-procedure)
- [Shutdown Procedure](#shutdown-procedure)
- [Health Checks](#health-checks)
- [Log Management](#log-management)
- [Data Management](#data-management)
- [Incident Response](#incident-response)
- [Routine Maintenance](#routine-maintenance)
- [Release Checklist](#release-checklist)
- [AWS Operations (Optional)](#aws-operations-optional)

## Service Overview

NimServerlessPipeline processes text payloads over HTTP and writes outputs to local storage and a JSONL database. The operational contract is deterministic and is verified by `./scripts/verify.sh`.

Key properties:

- **Stateless server**: The HTTP server is stateless, but it writes local artifacts.
- **Deterministic outputs**: The summary output is consistent across runs.
- **Single process**: The default runtime is a single Nim process.

## Startup Procedure

### Prerequisites

- Bash-compatible shell
- Network access (for Nim install via `choosenim`)
- `curl` and `python3` (used by the smoke test)

### Steps

1. Ensure you are in the repo root.
2. Run the startup script:

```bash
./scripts/run.sh
```

3. Confirm the server is running by hitting the health endpoint:

```bash
curl -sSf http://localhost:8080/health
```

### Expected Output

```json
{"status":"ok","mode":"local"}
```

### Notes

- The server runs in the foreground. Use a second terminal for client requests.
- The port can be changed using `NIM_PIPELINE_PORT`.

## Shutdown Procedure

If the server is running in the foreground, stop it with `Ctrl+C`.

If the server is running in the background:

```bash
pkill -f "backend/cli server"
```

## Health Checks

### Basic Health

The `/health` endpoint indicates server liveness and execution mode.

```bash
curl -sSf http://localhost:8080/health
```

### Local Artifact Checks

The pipeline writes files to:

- `./local_storage`
- `./local_db/records.jsonl`

Check that the files exist after a successful request:

```bash
ls -l local_storage
ls -l local_db/records.jsonl
```

## Log Management

Logs are written to `./logs/pipeline.log` by default.

### Viewing Logs

```bash
tail -n 50 logs/pipeline.log
```

### Clearing Logs

```bash
rm -f logs/pipeline.log
```

### Log Rotation

For long-running environments, consider log rotation:

- Use `logrotate` on Linux.
- Limit log size with external tooling.

## Data Management

### Storage Files

Each processed request yields a storage file. Over time, the `local_storage` directory can grow.

To clean up:

```bash
rm -rf local_storage
```

### Database Records

The JSONL file grows linearly with the number of requests. It is safe to archive or truncate.

Archive example:

```bash
cp local_db/records.jsonl /tmp/records-$(date +%Y%m%d).jsonl
> local_db/records.jsonl
```

### Backup Strategy

For local usage, backups are optional. If you need durability:

- Back up `local_storage` and `local_db` regularly.
- Compress old files to save space.

## Incident Response

### Server Not Responding

1. Confirm the process is running.
2. Check port usage:

```bash
lsof -i :8080
```

3. Check logs for errors.
4. Restart the server.

### Invalid Payloads

If clients are seeing `400` errors:

- Validate that the JSON payload is valid.
- Confirm `data` is not empty.
- Confirm payload size does not exceed limits.

### Missing Storage Files

If the API returns success but files are missing:

- Verify `NIM_PIPELINE_STORAGE_DIR`.
- Confirm directory permissions.
- Check for disk space issues.

### Missing Database Records

If `local_db/records.jsonl` is missing:

- Ensure `NIM_PIPELINE_DB_PATH` points to a writable location.
- Verify the parent directory exists.

## Routine Maintenance

### Weekly Checklist

- [ ] Run `./scripts/verify.sh` to ensure functionality.
- [ ] Archive or clean `local_storage` if needed.
- [ ] Trim `local_db/records.jsonl` if it grows too large.
- [ ] Check `logs/pipeline.log` for recurring errors.

### Monthly Checklist

- [ ] Review documentation for accuracy.
- [ ] Update Nim version if needed.
- [ ] Update CI workflow to align with new tooling.

## Release Checklist

Before a release, complete the following steps:

1. Run `./scripts/verify.sh` and ensure all tests pass.
2. Confirm README commands work as documented.
3. Update versioned documentation if required.
4. Ensure no binary artifacts are committed.
5. Ensure GitHub Actions passes on the PR.

## AWS Operations (Optional)

AWS mode is optional and requires additional setup. Only use this in environments with proper credentials and IAM roles.

### Deploying with SAM

```bash
export AWS_S3_BUCKET=your-bucket
cd infrastructure
./deploy.sh
```

### Verifying AWS Deployment

Once deployed:

- Check that the Lambda function exists.
- Confirm the API Gateway endpoint is deployed.
- Ensure the S3 bucket and DynamoDB table are present.

### Monitoring in AWS

- Use CloudWatch logs for Lambda.
- Use S3 object listings for storage verification.
- Use DynamoDB console for record verification.

### Rollback Strategy

To remove the stack:

```bash
aws cloudformation delete-stack --stack-name NimServerlessPipeline
```

### AWS Cost Considerations

Running AWS infrastructure incurs costs. Use local mode for development and CI to avoid unexpected charges.

## Appendix: Example Operational Scripts

### Health Check Script

```bash
#!/usr/bin/env bash
set -euo pipefail
curl -sSf http://localhost:8080/health
```

### Data Ingestion Script

```bash
#!/usr/bin/env bash
set -euo pipefail
curl -sSf -X POST http://localhost:8080/data \
  -H "Content-Type: application/json" \
  -d '{"data":"alpha beta alpha"}'
```

### Storage Verification Script

```bash
#!/usr/bin/env bash
set -euo pipefail
if ! ls local_storage/processed_*.txt >/dev/null 2>&1; then
  echo "No stored files found"
  exit 1
fi
```

## Appendix: Operational Notes

- Keep the server running in a dedicated terminal.
- Avoid running multiple instances with the same storage path.
- Ensure that any automation scripts clean up resources after tests.

