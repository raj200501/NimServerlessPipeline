import std/[os, strformat, json]
import config
import data_processor
import handler
import http_server
import utils

proc printUsage() =
  echo "NimServerlessPipeline CLI"
  echo "Usage:"
  echo "  nim c -r backend/cli.nim server"
  echo "  nim c -r backend/cli.nim process '<data>'"
  echo "  nim c -r backend/cli.nim lambda '<json>'"

proc runProcess(data: string) =
  let processed = processData(data)
  echo renderSummary(processed)

proc runLambda(payload: string) =
  let node = parseJson(payload)
  let response = handler(node, %*{})
  echo $response

proc main() =
  let cfg = loadConfig()
  setupLogging(cfg)
  ensureDirectories(cfg)

  if paramCount() < 1:
    printUsage()
    quit(1)

  let command = paramStr(1)
  case command
  of "server":
    startServer(cfg)
  of "process":
    if paramCount() < 2:
      echo "Missing data argument"
      quit(1)
    runProcess(paramStr(2))
  of "lambda":
    if paramCount() < 2:
      echo "Missing JSON payload"
      quit(1)
    runLambda(paramStr(2))
  else:
    printUsage()
    quit(1)

when isMainModule:
  main()
