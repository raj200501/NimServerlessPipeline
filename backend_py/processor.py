from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Dict, List


@dataclass
class WordCountResult:
    normalized_input: str
    word_counts: Dict[str, int]
    total_words: int
    unique_words: int
    processed_at: datetime


def normalize_input(data: str) -> str:
    return data.strip().lower()


def split_words(data: str) -> List[str]:
    cleaned_words: List[str] = []
    punctuation = "\n\t\r,.!?:;\"'()[]{}"
    for word in data.split():
        cleaned = word.strip(punctuation)
        if cleaned:
            cleaned_words.append(cleaned)
    return cleaned_words


def count_words(words: List[str]) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    for word in words:
        counts[word] = counts.get(word, 0) + 1
    return counts


def summarize_counts(counts: Dict[str, int]) -> str:
    parts = [f"{word}: {counts[word]}" for word in sorted(counts.keys())]
    return ", ".join(parts)


def process_data(data: str) -> WordCountResult:
    normalized = normalize_input(data)
    words = split_words(normalized)
    counts = count_words(words)
    return WordCountResult(
        normalized_input=normalized,
        word_counts=counts,
        total_words=len(words),
        unique_words=len(counts),
        processed_at=datetime.now(timezone.utc),
    )


def render_summary(result: WordCountResult) -> str:
    return (
        f"Processed {result.total_words} words "
        f"({result.unique_words} unique): {summarize_counts(result.word_counts)}"
    )
