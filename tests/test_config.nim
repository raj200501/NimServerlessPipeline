import unittest
import os
import config

suite "Config":
  test "Defaults load correctly":
    putEnv("NIM_PIPELINE_MODE", "")
    putEnv("NIM_PIPELINE_PORT", "")
    let cfg = loadConfig()
    check cfg.port == 8080
    check cfg.mode == pmLocal

  test "Overrides load correctly":
    putEnv("NIM_PIPELINE_MODE", "aws")
    putEnv("NIM_PIPELINE_PORT", "9090")
    let cfg = loadConfig()
    check cfg.mode == pmAws
    check cfg.port == 9090
