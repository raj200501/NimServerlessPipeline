from __future__ import annotations

import sys

from .handler import invoke_with_json
from .processor import process_data, render_summary
from .server import run_server


def print_usage() -> None:
    print("NimServerlessPipeline CLI")
    print("Usage:")
    print("  python -m backend_py.cli server")
    print("  python -m backend_py.cli process '<data>'")
    print("  python -m backend_py.cli lambda '<json>'")


def main() -> int:
    if len(sys.argv) < 2:
        print_usage()
        return 1

    command = sys.argv[1]
    if command == "server":
        run_server()
        return 0
    if command == "process":
        if len(sys.argv) < 3:
            print("Missing data argument")
            return 1
        result = process_data(sys.argv[2])
        print(render_summary(result))
        return 0
    if command == "lambda":
        if len(sys.argv) < 3:
            print("Missing JSON payload")
            return 1
        print(invoke_with_json(sys.argv[2]))
        return 0

    print_usage()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
