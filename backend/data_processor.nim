import strformat
import strutils
import sequtils
import tables
import threadpool

proc processData(data: string): string =
    let words = data.splitWhitespace()
    let wordCount = countTable[string]()

    parallel:
        for word in words:
            wordCount.inc(word)

    result = fmt"Processed data: {wordCount.toSeq().join()}"

when isMainModule:
    let data = "This is an example data string to be processed using Nim"
    let processedData = processData(data)
    echo processedData
