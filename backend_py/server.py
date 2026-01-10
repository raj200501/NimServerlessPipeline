from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, HTTPServer

from .config import load_config, ensure_directories
from .handler import handler


class RequestHandler(BaseHTTPRequestHandler):
    def _set_headers(self, status: int) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()

    def do_GET(self) -> None:
        if self.path != "/health":
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Not found"}).encode("utf-8"))
            return
        config = load_config()
        payload = {"status": "ok", "mode": config.mode}
        self._set_headers(200)
        self.wfile.write(json.dumps(payload).encode("utf-8"))

    def do_POST(self) -> None:
        if self.path != "/data":
            self._set_headers(404)
            self.wfile.write(json.dumps({"error": "Not found"}).encode("utf-8"))
            return
        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length == 0:
            self._set_headers(400)
            self.wfile.write(json.dumps({"error": "Request body is required"}).encode("utf-8"))
            return
        body = self.rfile.read(content_length).decode("utf-8")
        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            self._set_headers(400)
            self.wfile.write(json.dumps({"error": "Invalid JSON payload"}).encode("utf-8"))
            return
        response = handler(payload, {})
        status_code = response.get("statusCode", 500)
        self._set_headers(status_code)
        self.wfile.write(json.dumps(response.get("body", {})).encode("utf-8"))


class PipelineServer:
    def __init__(self) -> None:
        self.config = load_config()
        ensure_directories(self.config)
        self.httpd = HTTPServer(("0.0.0.0", self.config.port), RequestHandler)

    def serve_forever(self) -> None:
        self.httpd.serve_forever()


def run_server() -> None:
    server = PipelineServer()
    server.serve_forever()
