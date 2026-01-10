import unittest
import json
import os
import handler

suite "Lambda Handler":
  test "Handler processes data correctly":
    putEnv("NIM_PIPELINE_MODE", "local")
    putEnv("NIM_PIPELINE_STORAGE_DIR", getTempDir() / "handler_storage")
    putEnv("NIM_PIPELINE_DB_PATH", getTempDir() / "handler_db" / "records.jsonl")
    let event = %*{"data": "sample data"}
    let context = %*{}
    let response = handler(event, context)
    check response["statusCode"].getInt == 200
    let message = response["body"]["message"].getStr
    check message.contains("Processed")
