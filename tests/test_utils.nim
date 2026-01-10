import unittest
import os
import utils
import config

suite "Utils":
  test "Logging setup creates log file":
    let logPath = getTempDir() / "pipeline_logs" / "pipeline.log"
    putEnv("NIM_PIPELINE_LOG_PATH", logPath)
    let cfg = loadConfig()
    setupLogging(cfg)
    check fileExists(logPath)
