import std/[os, times, json]
import config


type
  StoredRecord* = object
    id*: string
    path*: string
    storedAt*: DateTime

proc appendRecord*(cfg: Config, id: string, payload: JsonNode): StoredRecord =
  let path = expandTilde(cfg.databasePath)
  let dir = splitPath(path).head
  if dir.len > 0:
    createDir(dir)
  let record = %*{
    "id": id,
    "storedAt": $now(),
    "payload": payload
  }
  let line = $record & "\n"
  let file = open(path, fmAppend)
  defer: file.close()
  file.write(line)
  result = StoredRecord(id: id, path: path, storedAt: now())

proc readAllRecords*(cfg: Config): seq[JsonNode] =
  let path = expandTilde(cfg.databasePath)
  if not fileExists(path):
    return @[]
  let lines = readFile(path).splitLines()
  for line in lines:
    if line.len == 0:
      continue
    result.add(parseJson(line))
