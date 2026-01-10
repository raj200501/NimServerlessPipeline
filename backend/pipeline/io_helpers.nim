import std/[os, strutils, sequtils, tables, json]
import ./records

proc readLinesSafe*(path: string): seq[string] =
  if not fileExists(path):
    return @[]
  readFile(path).splitLines()

proc writeLines*(path: string, lines: seq[string]) =
  createDir(parentDir(path))
  writeFile(path, lines.join("\n"))

proc readJsonLines*(path: string): seq[JsonNode] =
  if not fileExists(path):
    return @[]
  for line in readLinesSafe(path):
    if line.strip().len == 0:
      continue
    result.add(parseJson(line))

proc writeJsonLines*(path: string, nodes: seq[JsonNode]) =
  var lines: seq[string] = @[]
  for node in nodes:
    lines.add($node)
  writeLines(path, lines)

proc recordsToJsonLines*(collection: RecordCollection): seq[string] =
  for record in collection.records:
    var obj = %*{}
    obj["namespace"] = %record.key.namespace
    obj["id"] = %record.key.id
    for key, value in record.fields:
      obj[key] = %value.fieldValueToString()
    result.add($obj)

proc writeRecordCollection*(path: string, collection: RecordCollection) =
  writeLines(path, collection.recordsToJsonLines())

proc readRecordCollection*(path: string, namespace: string): RecordCollection =
  result = initCollection(namespace)
  for line in readLinesSafe(path):
    if line.strip().len == 0:
      continue
    let node = parseJson(line)
    if node.kind != JObject:
      continue
    var record = initRecord(namespace, $result.records.len)
    for key, value in node:
      if key in ["namespace", "id"]:
        continue
      record.fields[key] = FieldValue(kind: fieldString, strValue: value.getStr())
    result.addRecord(record)

proc appendLine*(path: string, line: string) =
  createDir(parentDir(path))
  if fileExists(path):
    writeFile(path, readFile(path) & "\n" & line)
  else:
    writeFile(path, line)

proc appendLines*(path: string, lines: seq[string]) =
  for line in lines:
    appendLine(path, line)

proc safeDelete*(path: string): bool =
  if fileExists(path):
    removeFile(path)
    true
  else:
    false

proc readKeyValueFile*(path: string): Table[string, string] =
  result = initTable[string, string]()
  for line in readLinesSafe(path):
    let trimmed = line.strip()
    if trimmed.len == 0 or trimmed.startsWith("#"):
      continue
    let idx = trimmed.find('=')
    if idx <= 0:
      continue
    let key = trimmed[0 ..< idx].strip()
    let value = trimmed[idx + 1 .. ^1].strip()
    result[key] = value

proc writeKeyValueFile*(path: string, values: Table[string, string]) =
  var lines: seq[string] = @[]
  for key, value in values:
    lines.add(key & "=" & value)
  writeLines(path, lines)

proc readGlob*(pattern: string): seq[string] =
  for path in walkFiles(pattern):
    result.add(path)

proc readJsonFile*(path: string): JsonNode =
  parseJson(readFile(path))

proc writeJsonFile*(path: string, node: JsonNode) =
  createDir(parentDir(path))
  writeFile(path, $node)
