import std/[strformat, strutils, tables, sequtils, times, algorithm]


type
  WordCountResult* = object
    normalizedInput*: string
    wordCounts*: Table[string, int]
    totalWords*: int
    uniqueWords*: int
    processedAt*: DateTime

proc normalizeInput*(data: string): string =
  data.strip().toLowerAscii()

proc splitWords*(data: string): seq[string] =
  result = @[]
  for word in data.splitWhitespace():
    let cleaned = word.strip(chars = {'\n', '\t', '\r', ',', '.', '!', '?', ':', ';', '"', '\'', '(', ')', '[', ']', '{', '}'})
    if cleaned.len > 0:
      result.add(cleaned)

proc countWords*(words: seq[string]): Table[string, int] =
  result = initTable[string, int]()
  for word in words:
    if result.hasKey(word):
      result[word] = result[word] + 1
    else:
      result[word] = 1

proc summarizeCounts*(counts: Table[string, int]): string =
  let sortedWords = counts.keys().toSeq().sorted(cmp[string])
  var parts: seq[string] = @[]
  for word in sortedWords:
    parts.add(fmt"{word}: {counts[word]}")
  result = parts.join(", ")

proc processData*(data: string): WordCountResult =
  let normalized = normalizeInput(data)
  let words = splitWords(normalized)
  let counts = countWords(words)
  result = WordCountResult(
    normalizedInput: normalized,
    wordCounts: counts,
    totalWords: words.len,
    uniqueWords: counts.len,
    processedAt: now()
  )

proc renderSummary*(result: WordCountResult): string =
  let countSummary = summarizeCounts(result.wordCounts)
  fmt"Processed {result.totalWords} words ({result.uniqueWords} unique): {countSummary}"

when isMainModule:
  let example = "This is an example data string to be processed using Nim"
  let processed = processData(example)
  echo renderSummary(processed)
