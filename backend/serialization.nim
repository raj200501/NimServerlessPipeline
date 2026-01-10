import std/[json, tables]

proc tableToJson*(counts: Table[string, int]): JsonNode =
  result = newJObject()
  for key, value in counts:
    result[key] = %value
