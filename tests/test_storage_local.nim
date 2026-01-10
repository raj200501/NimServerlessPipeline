import unittest
import os
import json
import config
import storage_local

suite "Local Storage":
  test "Writes plain data":
    putEnv("NIM_PIPELINE_STORAGE_DIR", getTempDir() / "storage_test")
    let cfg = loadConfig()
    let result = writeObject(cfg, "example.txt", "hello")
    check fileExists(result.path)
    check readFile(result.path) == "hello"

  test "Writes JSON payload":
    putEnv("NIM_PIPELINE_STORAGE_DIR", getTempDir() / "storage_test_json")
    let cfg = loadConfig()
    let payload = %*{"message": "hello"}
    let result = writeJsonObject(cfg, "example.json", payload)
    check fileExists(result.path)
    check readFile(result.path).contains("message")
