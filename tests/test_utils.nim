import unittest
import utils

suite "Test Utils":
  test "Logging setup":
    utils.setupLogging()
    check true  # Ensure no exceptions are raised
