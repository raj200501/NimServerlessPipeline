import unittest
import data_processor

suite "Test Data Processor":
  test "Data processing works correctly":
    let data = "word1 word2 word1"
    let result = data_processor.processData(data)
    check result.contains("word1: 2")
    check result.contains("word2: 1")
