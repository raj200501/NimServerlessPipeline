# Testing Guide

This document describes how testing is structured in NimServerlessPipeline, including unit tests and the integration smoke test.

## Test Layers

1. **Python unit tests**: Canonical tests for the local runtime.
2. **Integration smoke test**: End-to-end HTTP workflow with filesystem verification.
3. **Optional Nim tests**: Reference tests for the Nim implementation.
4. **Verification command**: `./scripts/verify.sh` runs the canonical tests.

## Python Unit Tests

Python tests are written using the standard `unittest` framework. They are deterministic and do not rely on external services.

### Running Python Unit Tests

```bash
./scripts/run_tests.sh
```

This script runs the following test files:

- `tests_py/test_config.py`
- `tests_py/test_processor.py`
- `tests_py/test_storage.py`
- `tests_py/test_database.py`
- `tests_py/test_handler.py`

### Coverage Summary

| Module | Test File | Coverage Summary |
| --- | --- | --- |
| `backend_py/config.py` | `tests_py/test_config.py` | Defaults and overrides. |
| `backend_py/processor.py` | `tests_py/test_processor.py` | Normalization and summaries. |
| `backend_py/storage.py` | `tests_py/test_storage.py` | File writes. |
| `backend_py/database.py` | `tests_py/test_database.py` | JSONL append/read. |
| `backend_py/handler.py` | `tests_py/test_handler.py` | Handler response structure. |

## Integration Smoke Test

The smoke test is implemented in `scripts/smoke_test.sh`. It validates that the pipeline works end-to-end:

1. Starts the HTTP server on a fixed port.
2. Hits `/health` to confirm server is running.
3. Posts data to `/data` and validates the response.
4. Checks for a stored summary file.
5. Checks for a JSONL record file.

### Running the Smoke Test

```bash
./scripts/smoke_test.sh
```

### What the Smoke Test Validates

- The server starts and accepts requests.
- The handler processes input and responds with the expected fields.
- Local storage and database artifacts are written.

## Optional Nim Tests

Nim tests remain under `tests/` for the Lambda reference implementation. They are not part of the canonical verification path but can be run if you have Nim installed.

Example:

```bash
nim c -r --path:backend tests/test_data_processor.nim
```

## CI Verification

The canonical verification command is:

```bash
./scripts/verify.sh
```

This is the same command executed in CI (`.github/workflows/ci.yml`). It ensures that unit and integration tests pass.

## Writing New Tests

To add a new Python module test:

1. Create a test file under `tests_py/`.
2. Add `unittest` suites with deterministic assertions.
3. Ensure the test file matches the discovery pattern (`test_*.py`).

### Example Test Template

```python
import unittest

class MyFeatureTests(unittest.TestCase):
    def test_behavior(self):
        self.assertTrue(True)
```

## Common Test Pitfalls

- **Environment variables**: Tests should set their own env vars to avoid interference.
- **Filesystem side effects**: Use temporary directories where possible.
- **Ordering**: Word counts are sorted to ensure deterministic output.

## Debugging Test Failures

- Run the failing test file manually with `python3 -m unittest tests_py.test_processor`.
- Check logs under `./logs` if the failure is server-related.
- Verify local storage files under `./local_storage` and `./local_db`.

## Future Testing Enhancements

- Add property-based tests for data processing.
- Add HTTP contract tests using a Python HTTP client.
- Add concurrency tests if/when async processing is added.

