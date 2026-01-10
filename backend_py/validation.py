from __future__ import annotations


def ensure_non_empty(value: str, field_name: str) -> None:
    if not value:
        raise ValueError(f"{field_name} must not be empty")


def ensure_max_bytes(value: str, field_name: str, max_bytes: int) -> None:
    if len(value.encode("utf-8")) > max_bytes:
        raise ValueError(f"{field_name} exceeds {max_bytes} bytes")
