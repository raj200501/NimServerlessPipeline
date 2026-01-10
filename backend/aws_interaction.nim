import std/[osproc, strformat, os, json, logging]
import config
import storage_local
import database_local

proc awsArgs(cfg: Config): seq[string] =
  result = @["--region", cfg.awsRegion]
  if cfg.awsProfile.len > 0:
    result.add(@["--profile", cfg.awsProfile])

proc ensureAwsCli*(): bool =
  try:
    discard execProcess("aws", args = @["--version"], options = {poUsePath, poStdErrToStdOut})
    result = true
  except OSError:
    result = false

proc uploadToS3*(cfg: Config, key: string, data: string): string =
  if cfg.mode == pmAws:
    if not ensureAwsCli():
      raise newException(OSError, "AWS CLI not found. Install awscli or use local mode.")
    let filePath = getTempDir() / key
    writeFile(filePath, data)
    let args = @["s3", "cp", filePath, fmt"s3://{cfg.awsBucket}/{key}"] & awsArgs(cfg)
    let output = execProcess("aws", args = args, options = {poUsePath, poStdErrToStdOut})
    logging.info fmt"Uploaded {key} to S3 bucket {cfg.awsBucket}"
    logging.info output
    return fmt"s3://{cfg.awsBucket}/{key}"
  let stored = writeObject(cfg, key, data)
  logging.info fmt"Stored {key} locally at {stored.path}"
  stored.path

proc persistRecord*(cfg: Config, id: string, payload: JsonNode): string =
  if cfg.mode == pmAws:
    if not ensureAwsCli():
      raise newException(OSError, "AWS CLI not found. Install awscli or use local mode.")
    let args = @["dynamodb", "put-item", "--table-name", "NimTable", "--item", $payload] & awsArgs(cfg)
    let output = execProcess("aws", args = args, options = {poUsePath, poStdErrToStdOut})
    logging.info fmt"Persisted record {id} to DynamoDB"
    logging.info output
    return "aws://dynamodb/NimTable"
  let record = appendRecord(cfg, id, payload)
  logging.info fmt"Persisted record {id} locally at {record.path}"
  record.path
