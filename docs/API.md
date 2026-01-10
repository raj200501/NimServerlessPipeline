# API Reference

The local runtime exposes a small HTTP API intended to mirror the behavior of a serverless API Gateway + Lambda integration. All endpoints return JSON and use standard HTTP response codes.

Base URL: `http://localhost:<port>`

## GET /health

Returns a health response indicating that the server is running and the current execution mode.

### Request

```
GET /health
```

### Response

Status: `200 OK`

```json
{
  "status": "ok",
  "mode": "local"
}
```

### Example

```bash
curl -sSf http://localhost:8080/health
```

## POST /data

Accepts a JSON payload containing text data. The server processes the data and stores both the summary output and a structured record.

### Request

```
POST /data
Content-Type: application/json
```

Payload:

```json
{
  "data": "alpha beta alpha"
}
```

### Response

Status: `200 OK`

```json
{
  "message": "Processed data: Processed 3 words (2 unique): alpha: 2, beta: 1",
  "recordId": "rec_20240101120000",
  "storageKey": "processed_20240101120000.txt"
}
```

### Example

```bash
curl -sSf -X POST http://localhost:8080/data \
  -H "Content-Type: application/json" \
  -d '{"data":"alpha beta alpha"}'
```

## Error Responses

### Missing Data Field

Status: `400 Bad Request`

```json
{
  "error": "Missing 'data' field"
}
```

### Invalid JSON

Status: `400 Bad Request`

```json
{
  "error": "Invalid JSON payload"
}
```

### Empty Data

Status: `400 Bad Request`

```json
{
  "error": "data must not be empty"
}
```

### Oversized Payload

Status: `400 Bad Request`

```json
{
  "error": "data exceeds 1048576 bytes"
}
```

## Local Storage Side Effects

After a successful request, the following artifacts are produced:

1. A summary file under `NIM_PIPELINE_STORAGE_DIR`.
2. A JSONL record in `NIM_PIPELINE_DB_PATH`.

These artifacts are used by the integration smoke tests to verify correct behavior.

## Contract Notes

The contract is intentionally small and deterministic so that the project can be validated in CI environments without relying on external services. The response body mirrors what the Lambda handler returns in serverless mode, so that the same input/output tests can be reused.

## Example Scripted Run

```bash
export NIM_PIPELINE_MODE=local
export NIM_PIPELINE_PORT=8080
./scripts/run.sh
```

In a separate terminal:

```bash
curl -sSf http://localhost:8080/health
curl -sSf -X POST http://localhost:8080/data \
  -H "Content-Type: application/json" \
  -d '{"data":"lorem ipsum lorem"}'
```

The output can be verified in the local storage directory and the JSONL database file.

## API Design Rationale

The API keeps a minimal surface area for clarity and determinism:

- `/health` provides a static response for monitoring.
- `/data` accepts a single field to avoid ambiguity.

If you want to expand the API, consider:

- Adding metadata fields such as `sourceId` or `customerId`.
- Supporting a `metadata` object with optional fields.
- Adding an endpoint for retrieving the latest stored records.

