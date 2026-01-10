import std/[os, strformat, strutils]


type
  PipelineMode* = enum
    pmLocal,
    pmAws

  Config* = object
    mode*: PipelineMode
    port*: int
    storageDir*: string
    databasePath*: string
    logPath*: string
    maxPayloadBytes*: int
    awsBucket*: string
    awsRegion*: string
    awsProfile*: string

const
  DefaultPort = 8080
  DefaultMaxPayload = 1024 * 1024
  DefaultStorageDir = "./local_storage"
  DefaultDatabasePath = "./local_db/records.jsonl"
  DefaultLogPath = "./logs/pipeline.log"
  DefaultBucket = "nim-local-bucket"
  DefaultRegion = "us-east-1"

proc parseMode(value: string): PipelineMode =
  case value.toLowerAscii()
  of "aws": pmAws
  else: pmLocal

proc getEnvInt(name: string, fallback: int): int =
  let raw = getEnv(name)
  if raw.len == 0:
    return fallback
  try:
    result = parseInt(raw)
  except ValueError:
    result = fallback

proc loadConfig*(): Config =
  let mode = parseMode(getEnv("NIM_PIPELINE_MODE"))
  result = Config(
    mode: mode,
    port: getEnvInt("NIM_PIPELINE_PORT", DefaultPort),
    storageDir: getEnv("NIM_PIPELINE_STORAGE_DIR", DefaultStorageDir),
    databasePath: getEnv("NIM_PIPELINE_DB_PATH", DefaultDatabasePath),
    logPath: getEnv("NIM_PIPELINE_LOG_PATH", DefaultLogPath),
    maxPayloadBytes: getEnvInt("NIM_PIPELINE_MAX_PAYLOAD", DefaultMaxPayload),
    awsBucket: getEnv("NIM_PIPELINE_AWS_BUCKET", DefaultBucket),
    awsRegion: getEnv("NIM_PIPELINE_AWS_REGION", DefaultRegion),
    awsProfile: getEnv("NIM_PIPELINE_AWS_PROFILE")
  )

proc ensureDirectories*(config: Config) =
  let storageDir = expandTilde(config.storageDir)
  let logDir = expandTilde(splitPath(config.logPath).head)
  let dbDir = expandTilde(splitPath(config.databasePath).head)
  if storageDir.len > 0:
    createDir(storageDir)
  if logDir.len > 0:
    createDir(logDir)
  if dbDir.len > 0:
    createDir(dbDir)

proc describe*(config: Config): string =
  let modeLabel = if config.mode == pmAws: "aws" else: "local"
  fmt"mode={modeLabel} port={config.port} storageDir={config.storageDir} dbPath={config.databasePath} logPath={config.logPath} maxPayload={config.maxPayloadBytes}"
