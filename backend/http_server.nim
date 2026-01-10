import std/[asynchttpserver, asyncdispatch, json, strformat, logging]
import handler
import config
import utils

proc respondJson(req: Request, statusCode: HttpCode, payload: JsonNode): Future[void] {.async.} =
  await req.respond(statusCode, $payload, newHttpHeaders({"Content-Type": "application/json"}))

proc handleRequest*(req: Request, cfg: Config): Future[void] {.async.} =
  if req.url.path == "/health" and req.reqMethod == HttpGet:
    await respondJson(req, Http200, %*{"status": "ok", "mode": $(if cfg.mode == pmAws: "aws" else: "local")})
    return

  if req.url.path == "/data" and req.reqMethod == HttpPost:
    let body = req.body
    if body.len == 0:
      await respondJson(req, Http400, %*{"error": "Request body is required"})
      return
    try:
      let payload = parseJson(body)
      let response = handler(payload, %*{})
      let statusCode = response["statusCode"].getInt
      let bodyPayload = response["body"]
      await respondJson(req, HttpCode(statusCode), bodyPayload)
    except JsonParsingError:
      await respondJson(req, Http400, %*{"error": "Invalid JSON payload"})
    return

  await respondJson(req, Http404, %*{"error": "Not found"})

proc startServer*(cfg: Config) =
  setupLogging(cfg)
  ensureDirectories(cfg)
  logging.info fmt"Starting HTTP server on port {cfg.port} ({describe(cfg)})"
  let server = newAsyncHttpServer()
  let handlerProc = proc (req: Request) {.async.} =
    await handleRequest(req, cfg)
  waitFor server.serve(Port(cfg.port), handlerProc)

when isMainModule:
  let cfg = loadConfig()
  startServer(cfg)
