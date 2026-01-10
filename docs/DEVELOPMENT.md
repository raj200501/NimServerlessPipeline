# Development Guide

This guide documents the development workflow for NimServerlessPipeline. The canonical local runtime is the Python implementation under `backend_py/`. Nim sources remain for Lambda reference builds.

## Repository Layout

```
backend/           # Nim source code (Lambda reference)
backend_py/        # Python runtime used for local execution
infrastructure/    # AWS SAM template
scripts/           # Local dev and CI scripts
tests/             # Nim unit tests (optional)
tests_py/          # Python unit tests (canonical)
```

## Setting Up a Local Environment

1. Clone the repo.
2. Ensure Python 3 is available.
3. Run `./scripts/run.sh` to start the server.

The Nim toolchain is optional and only required for building the Lambda binary.

## Recommended Workflow

```bash
./scripts/run_tests.sh
./scripts/run.sh
```

Then hit the HTTP endpoints using curl as described in the README.

## Running the Python Runtime Manually

```bash
python3 -m backend_py.cli server
```

You can invoke the handler directly:

```bash
python3 -m backend_py.cli lambda '{"data":"example"}'
```

## Building the Nim Reference (Optional)

If you prefer manual compilation of the Nim reference implementation:

```bash
nim c --path:backend backend/cli.nim
./backend/cli server
```

You can also run the Lambda-compatible handler:

```bash
nim c -r --path:backend backend/cli.nim lambda '{"data":"example"}'
```

## Editing Modules

### Data Processing

Python file: `backend_py/processor.py`
Nim file: `backend/data_processor.nim`

- `normalize_input` / `normalizeInput` ensures consistent casing and whitespace.
- `split_words` / `splitWords` handles punctuation stripping.
- `count_words` / `countWords` produces a deterministic table.
- `render_summary` / `renderSummary` renders a stable summary string.

### Storage

Local storage logic lives in `backend_py/storage.py` for the Python runtime, with a Nim reference in `backend/storage_local.nim`. It writes the summary to a plain text file.

### Database

Local database logic is in `backend_py/database.py`, with a Nim reference in `backend/database_local.nim`. It appends JSON lines to `records.jsonl`.

### HTTP Server

- Python file: `backend_py/server.py`
- Nim file: `backend/http_server.nim`
- Endpoints: `/health`, `/data`

Add new endpoints by updating the routing logic in the corresponding server module.

## Adding Dependencies

Python dependencies are not required for the default runtime. If you add dependencies:

1. Vendor them or add a requirements file.
2. Update `scripts/run_tests.sh` and `scripts/verify.sh` to install them.
3. Ensure CI runs the updated scripts.

If you add Nim dependencies:

1. Add a `nimble` file (optional in this repo).
2. Update `scripts/bootstrap_nim.sh` to install dependencies.
3. Ensure optional Nim build steps pass locally.

## Debugging Tips

- Logs are written to `./logs/pipeline.log` by default.
- Use `NIM_PIPELINE_LOG_PATH` to redirect logs.
- Use `NIM_PIPELINE_PORT` if your default port is busy.

## Local Artifact Cleanup

The pipeline writes to `local_storage` and `local_db`. You can remove them with:

```bash
rm -rf local_storage local_db logs
```

## Code Style

- Keep module boundaries clear.
- Prefer deterministic outputs.
- Keep handlers thin; push logic into dedicated modules.

## Adding New Scripts

Place new scripts under `scripts/` and ensure they are executable. If you add a script that should run in CI, update `.github/workflows/ci.yml`.

## Documentation Updates

When you add new features or change behavior:

1. Update README for user-facing commands.
2. Update `docs/API.md` for HTTP changes.
3. Update `docs/CONFIGURATION.md` for config changes.
4. Add or update tests to keep verification deterministic.

## Release Considerations

- Ensure `./scripts/verify.sh` passes before tagging a release.
- Keep the Nim version pinned in `scripts/bootstrap_nim.sh` if you rely on it.
- Avoid committing binaries; the repo should stay text-only.

## Future Enhancements

- Add a local web UI for inspection.
- Add a JSON schema for requests/responses.
- Add a persistence abstraction for plugging in other databases.

