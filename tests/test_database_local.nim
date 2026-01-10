import unittest
import os
import json
import config
import database_local

suite "Local Database":
  test "Appends and reads records":
    putEnv("NIM_PIPELINE_DB_PATH", getTempDir() / "db_test" / "records.jsonl")
    let cfg = loadConfig()
    let payload = %*{"value": "one"}
    discard appendRecord(cfg, "record1", payload)
    let records = readAllRecords(cfg)
    check records.len == 1
    check records[0]["payload"]["value"].getStr == "one"
