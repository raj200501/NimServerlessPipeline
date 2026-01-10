import std/[os, strformat, times, json]
import config


type
  StoredObject* = object
    key*: string
    path*: string
    sizeBytes*: int
    storedAt*: DateTime

proc storagePath*(cfg: Config, key: string): string =
  let safeKey = key.replace("/", "_")
  let base = expandTilde(cfg.storageDir)
  createDir(base)
  base / safeKey

proc writeObject*(cfg: Config, key: string, data: string): StoredObject =
  let path = storagePath(cfg, key)
  writeFile(path, data)
  result = StoredObject(
    key: key,
    path: path,
    sizeBytes: data.len,
    storedAt: now()
  )

proc writeJsonObject*(cfg: Config, key: string, payload: JsonNode): StoredObject =
  writeObject(cfg, key, $payload)
