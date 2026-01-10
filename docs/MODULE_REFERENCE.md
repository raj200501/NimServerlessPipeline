# Module Reference

This document provides a module-by-module reference for NimServerlessPipeline. The canonical local runtime is implemented in Python under `backend_py/`, while the Nim modules under `backend/` provide a Lambda-compatible reference implementation.

## Table of Contents

- [Python Runtime](#python-runtime)
  - [backend_py/config.py](#backend_pyconfigpy)
  - [backend_py/processor.py](#backend_pyprocessorpy)
  - [backend_py/storage.py](#backend_pystoragepy)
  - [backend_py/database.py](#backend_pydatabasepy)
  - [backend_py/validation.py](#backend_pyvalidationpy)
  - [backend_py/aws_interaction.py](#backend_pyaws_interactionpy)
  - [backend_py/handler.py](#backend_pyhandlerpy)
  - [backend_py/server.py](#backend_pyserverpy)
  - [backend_py/cli.py](#backend_pyclipy)
- [Nim Reference](#nim-reference)
  - [backend/config.nim](#backendconfignim)
  - [backend/utils.nim](#backendutilsnim)
  - [backend/data_processor.nim](#backenddata_processornim)
  - [backend/serialization.nim](#backendserializationnim)
  - [backend/storage_local.nim](#backendstorage_localnim)
  - [backend/database_local.nim](#backenddatabase_localnim)
  - [backend/aws_interaction.nim](#backendaws_interactionnim)
  - [backend/validation.nim](#backendvalidationnim)
  - [backend/handler.nim](#backendhandlernim)
  - [backend/http_server.nim](#backendhttp_servernim)
  - [backend/cli.nim](#backendclinim)
- [Scripts](#scripts)
  - [scripts/bootstrap_nim.sh](#scriptsbootstrap_nimsh)
  - [scripts/run.sh](#scriptsrunsh)
  - [scripts/run_tests.sh](#scriptsrun_testssh)
  - [scripts/smoke_test.sh](#scriptssmoke_testsh)
  - [scripts/verify.sh](#scriptsverifysh)

## Python Runtime

### backend_py/config.py

**Purpose**

Centralized configuration for the pipeline. Reads environment variables and exposes defaults.

**Key Types**

- `Config`: dataclass containing all configuration fields.

**Key Functions**

- `load_config()`: Reads environment variables and returns a `Config`.
- `ensure_directories(config)`: Creates directories for storage, database, and logging.
- `describe(config)`: Returns a human-readable summary string.

### backend_py/processor.py

**Purpose**

Contains the core text processing logic.

**Key Types**

- `WordCountResult`: Dataclass containing normalized input, word counts, and metadata.

**Key Functions**

- `normalize_input(data)`: Lowercases and trims the input string.
- `split_words(data)`: Splits the input and strips punctuation.
- `count_words(words)`: Builds a word count dictionary.
- `summarize_counts(counts)`: Produces a deterministic summary string.
- `process_data(data)`: Runs the full processing pipeline.
- `render_summary(result)`: Renders a human-readable summary.

### backend_py/storage.py

**Purpose**

Local filesystem storage implementation.

**Key Types**

- `StoredObject`: metadata about stored files.

**Key Functions**

- `storage_path(config, key)`: Returns a filesystem path for the given key.
- `write_object(config, key, data)`: Writes data to disk.

### backend_py/database.py

**Purpose**

Local JSONL database implementation.

**Key Types**

- `StoredRecord`: metadata about appended records.

**Key Functions**

- `append_record(config, record_id, payload)`: Appends a record to the JSONL file.
- `read_all_records(config)`: Reads all records into memory.

### backend_py/validation.py

**Purpose**

Input validation helpers.

**Key Functions**

- `ensure_non_empty(value, field_name)`: Ensures a string is not empty.
- `ensure_max_bytes(value, field_name, max_bytes)`: Ensures a string is under a size limit.

### backend_py/aws_interaction.py

**Purpose**

Abstracted persistence layer that chooses between local and AWS modes.

**Key Functions**

- `upload_to_s3(config, key, data)`: Writes to local storage or S3.
- `persist_record(config, record_id, payload)`: Writes to local DB or DynamoDB.
- `ensure_aws_cli()`: Verifies that the AWS CLI is installed.

### backend_py/handler.py

**Purpose**

Lambda-compatible handler that orchestrates processing and persistence.

**Key Functions**

- `handler(event, context)`: Processes input JSON and returns a response JSON.
- `invoke_with_json(payload)`: Utility for CLI invocation.

### backend_py/server.py

**Purpose**

Local HTTP server implementation.

**Key Components**

- `RequestHandler`: HTTP request handler with `/health` and `/data` routes.
- `PipelineServer`: Thin wrapper that binds to the configured port.
- `run_server()`: Launches the server.

### backend_py/cli.py

**Purpose**

Command-line interface entrypoint.

**Commands**

- `server`: starts the HTTP server.
- `process <data>`: processes a string locally and prints the summary.
- `lambda <json>`: invokes the Lambda handler with the provided JSON.

## Nim Reference

The Nim modules mirror the same behavior and are primarily used for the optional Lambda build. They are not required for the Python-based local runtime but are kept for parity.

### backend/config.nim

**Purpose**

Centralized configuration for the pipeline (Nim reference).

### backend/utils.nim

**Purpose**

Logging setup for the Nim implementation.

### backend/data_processor.nim

**Purpose**

Text processing pipeline in Nim.

### backend/serialization.nim

**Purpose**

Conversion helpers between Nim tables and JSON.

### backend/storage_local.nim

**Purpose**

Local filesystem storage for the Nim implementation.

### backend/database_local.nim

**Purpose**

Local JSONL database writer for the Nim implementation.

### backend/aws_interaction.nim

**Purpose**

AWS/local persistence layer for the Nim implementation.

### backend/validation.nim

**Purpose**

Input validation helpers for the Nim implementation.

### backend/handler.nim

**Purpose**

Lambda-compatible handler for the Nim implementation.

### backend/http_server.nim

**Purpose**

HTTP server reference for the Nim implementation.

### backend/cli.nim

**Purpose**

CLI entrypoint for the Nim implementation.

## Scripts

### scripts/bootstrap_nim.sh

**Purpose**

Installs Nim deterministically using `choosenim`. Optional; used only for Nim builds.

### scripts/run.sh

**Purpose**

Starts the local HTTP server with sensible defaults (Python runtime).

### scripts/run_tests.sh

**Purpose**

Runs the Python unit tests.

### scripts/smoke_test.sh

**Purpose**

End-to-end verification of the local pipeline.

### scripts/verify.sh

**Purpose**

Canonical verification entrypoint for CI.

## Appendix: Example Imports

Example import list for a new Python module:

```python
from backend_py.config import load_config
```

Example usage of the handler:

```python
from backend_py.handler import handler

response = handler({"data": "example"}, {})
```

