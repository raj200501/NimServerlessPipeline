import unittest
import data_processor

suite "Data Processor":
  test "Processes and normalizes data":
    let data = "Word1 word2 word1"
    let result = processData(data)
    check result.totalWords == 3
    check result.uniqueWords == 2
    check result.wordCounts["word1"] == 2
    check result.wordCounts["word2"] == 1

  test "Summary is deterministic":
    let data = "banana apple banana"
    let result = processData(data)
    let summary = renderSummary(result)
    check summary.contains("apple: 1")
    check summary.contains("banana: 2")
