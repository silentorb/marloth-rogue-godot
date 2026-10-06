#!/usr/bin/env bash
# HTTP build agent for marloth-win (compose-network only; no host port publish).
# GET /health → 200
# GET|POST /build → flock + ./scripts/build-windows-natives.sh; body is full log; HTTP 200/500 from exit
# Overlapping builds → 409
# Natives only — Godot Windows Desktop export runs on the marloth service.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${MARLOTH_WIN_AGENT_PORT:-9876}"
LOCK_FILE="${TMPDIR:-/tmp}/marloth-win-build.lock"
BUILD_SCRIPT="${ROOT}/scripts/build-windows-natives.sh"

export PYTHONUNBUFFERED=1

exec python3 - "$PORT" "$LOCK_FILE" "$BUILD_SCRIPT" <<'PY'
import fcntl
import os
import subprocess
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

port = int(sys.argv[1])
lock_path = sys.argv[2]
build_script = sys.argv[3]
repo_root = os.path.abspath(os.path.join(os.path.dirname(build_script), ".."))


class Handler(BaseHTTPRequestHandler):
	protocol_version = "HTTP/1.1"

	def log_message(self, fmt, *args):
		sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

	def _send(self, code, body: bytes, content_type="text/plain; charset=utf-8"):
		self.send_response(code)
		self.send_header("Content-Type", content_type)
		self.send_header("Content-Length", str(len(body)))
		self.send_header("Connection", "close")
		self.end_headers()
		if body:
			self.wfile.write(body)

	def do_GET(self):
		path = self.path.split("?", 1)[0]
		if path == "/health":
			self._send(200, b"ok\n")
			return
		if path == "/build":
			self._run_build()
			return
		self._send(404, b"not found\n")

	def do_POST(self):
		path = self.path.split("?", 1)[0]
		if path == "/build":
			length = int(self.headers.get("Content-Length", "0") or "0")
			if length:
				self.rfile.read(length)
			self._run_build()
			return
		self._send(404, b"not found\n")

	def _run_build(self):
		lock_fd = open(lock_path, "a+", encoding="utf-8")
		try:
			fcntl.flock(lock_fd.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
		except BlockingIOError:
			lock_fd.close()
			self._send(409, b"build already in progress\n")
			return

		log_path = None
		exit_code = 1
		try:
			sys.stderr.write("marloth-win build agent: starting build-windows-natives.sh\n")
			with tempfile.NamedTemporaryFile(
				mode="w+b", delete=False, prefix="marloth-win-build-"
			) as logf:
				log_path = logf.name
				logf.write(b"marloth-win build agent: starting build-windows-natives.sh\n")
				logf.flush()
				proc = subprocess.Popen(
					[build_script],
					cwd=repo_root,
					stdout=logf,
					stderr=subprocess.STDOUT,
				)
				exit_code = proc.wait()
				logf.write(("\nmarloth-win build agent: exit %d\n" % exit_code).encode())
			with open(log_path, "rb") as rf:
				body = rf.read()
			# Mirror log to container stderr for `docker compose logs marloth-win`.
			sys.stderr.buffer.write(body)
			sys.stderr.buffer.flush()
			status = 200 if exit_code == 0 else 500
			self._send(status, body)
		except Exception as exc:  # noqa: BLE001
			msg = ("marloth-win build agent error: %s\n" % exc).encode()
			sys.stderr.buffer.write(msg)
			self._send(500, msg)
		finally:
			fcntl.flock(lock_fd.fileno(), fcntl.LOCK_UN)
			lock_fd.close()
			if log_path:
				try:
					os.unlink(log_path)
				except OSError:
					pass


httpd = ThreadingHTTPServer(("0.0.0.0", port), Handler)
sys.stderr.write("marloth-win build agent listening on 0.0.0.0:%s\n" % port)
httpd.serve_forever()
PY
