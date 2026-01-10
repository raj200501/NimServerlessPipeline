import std/[strformat]

proc ensureNonEmpty*(value: string, fieldName: string) =
  if value.len == 0:
    raise newException(ValueError, fmt"{fieldName} must not be empty")

proc ensureMaxBytes*(value: string, fieldName: string, maxBytes: int) =
  if value.len > maxBytes:
    raise newException(ValueError, fmt"{fieldName} exceeds {maxBytes} bytes")
