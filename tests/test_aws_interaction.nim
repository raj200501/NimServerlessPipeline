import unittest
import os
import json
import aws_interaction
import config

suite "Storage Interaction":
  test "Local upload stores data":
    putEnv("NIM_PIPELINE_MODE", "local")
    putEnv("NIM_PIPELINE_STORAGE_DIR", getTempDir() / "aws_storage")
    let cfg = loadConfig()
    let path = uploadToS3(cfg, "test_data.txt", "sample data")
    check fileExists(path)

  test "Local persistence stores record":
    putEnv("NIM_PIPELINE_MODE", "local")
    putEnv("NIM_PIPELINE_DB_PATH", getTempDir() / "aws_db" / "records.jsonl")
    let cfg = loadConfig()
    let payload = %*{"id": "test", "value": "data"}
    let path = persistRecord(cfg, "test", payload)
    check fileExists(path)
