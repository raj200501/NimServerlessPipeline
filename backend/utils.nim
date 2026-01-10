import std/[logging, os]
import config

proc setupLogging*(cfg: Config) =
  let logFile = expandTilde(cfg.logPath)
  let logDir = splitPath(logFile).head
  if logDir.len > 0:
    createDir(logDir)
  if not fileExists(logFile):
    writeFile(logFile, "")
  let handler = newFileHandler(logFile, LogLevel.Info)
  logging.addHandler(handler)
  logging.addHandler(newConsoleHandler())

when isMainModule:
  let cfg = loadConfig()
  setupLogging(cfg)
  logging.info "Logging setup complete"
