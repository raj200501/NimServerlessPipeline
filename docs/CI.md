# CI / GitHub Actions

This document explains the CI setup for NimServerlessPipeline.

## Workflow Overview

The CI workflow is defined in `.github/workflows/ci.yml`. It performs the following steps:

1. Check out the repository.
2. Run `./scripts/verify.sh`.

The verification script runs Python unit tests and executes the smoke test against the local HTTP server.

## Why a Single Verification Command

Having a single entrypoint ensures parity between local development and CI. When a developer runs:

```bash
./scripts/verify.sh
```

they are running the exact same checks that CI runs.

## Dependency Management

The repo does not commit binaries. The CI job relies on the Python runtime available on the GitHub-hosted runner. Nim is optional and only needed for Lambda builds; it is not required for the canonical verification path.

## Determinism

The CI checks are deterministic because:

- Unit tests set their own environment variables.
- Local storage directories are predictable.
- The smoke test uses fixed inputs.

## Extending the Workflow

If you add new scripts or tests:

1. Update `scripts/verify.sh`.
2. Confirm `scripts/verify.sh` passes locally.
3. Commit your changes and ensure CI passes.

## Common CI Failures

- **Missing executable bits**: ensure scripts are executable (`chmod +x`).
- **Port conflicts**: the smoke test uses port 8090; ensure it is free.
- **Missing Python**: ensure the runner has Python 3 (GitHub-hosted runners do).

## Suggested Enhancements

- Add caching for Python dependencies if you introduce them.
- Add linting or formatting scripts.
- Add a separate workflow for AWS deployment (optional and manual).

