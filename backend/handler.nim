import std/[json, logging, strformat, times]
import aws_interaction
import data_processor
import config
import validation
import utils
import serialization

proc handler*(event: JsonNode, context: JsonNode): JsonNode {.exportc.} =
  let cfg = loadConfig()
  setupLogging(cfg)
  ensureDirectories(cfg)

  let dataNode = event{"data"}
  if dataNode.isNil:
    return %*{"statusCode": 400, "body": %*{"error": "Missing 'data' field"}}

  let data = dataNode.getStr
  try:
    ensureNonEmpty(data, "data")
    ensureMaxBytes(data, "data", cfg.maxPayloadBytes)
  except ValueError as e:
    return %*{"statusCode": 400, "body": %*{"error": e.msg}}

  logging.info fmt"Received data ({data.len} bytes)"
  let processed = processData(data)
  let summary = renderSummary(processed)

  let timestamp = processed.processedAt.format("yyyyMMddHHmmss")
  let key = fmt"processed_{timestamp}.txt"
  let recordId = fmt"rec_{timestamp}"

  discard uploadToS3(cfg, key, summary)
  let recordPayload = %*{
    "id": recordId,
    "receivedAt": $now(),
    "summary": summary,
    "wordCounts": tableToJson(processed.wordCounts),
    "totalWords": processed.totalWords,
    "uniqueWords": processed.uniqueWords
  }
  discard persistRecord(cfg, recordId, recordPayload)

  result = %*{
    "statusCode": 200,
    "body": %*{
      "message": fmt"Processed data: {summary}",
      "recordId": recordId,
      "storageKey": key
    }
  }
