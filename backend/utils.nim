import logging

proc setupLogging() =
    let logFile = "/tmp/nim_serverless.log"
    let handler = newFileHandler(logFile, LogLevel.Info)
    logging.addHandler(handler)

when isMainModule:
    setupLogging()
    logging.info "Logging setup complete"
