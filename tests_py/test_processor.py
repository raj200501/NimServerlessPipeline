from __future__ import annotations

import unittest

from backend_py.processor import process_data, render_summary


class ProcessorTests(unittest.TestCase):
    def test_counts_words(self) -> None:
        result = process_data("Word1 word2 word1")
        self.assertEqual(result.total_words, 3)
        self.assertEqual(result.unique_words, 2)
        self.assertEqual(result.word_counts["word1"], 2)
        self.assertEqual(result.word_counts["word2"], 1)

    def test_summary_is_deterministic(self) -> None:
        result = process_data("banana apple banana")
        summary = render_summary(result)
        self.assertIn("apple: 1", summary)
        self.assertIn("banana: 2", summary)


if __name__ == "__main__":
    unittest.main()
