#!/usr/bin/env python3
"""Pass-through proxy for the tests: forwards every request to a dev server and
puts PAYLOAD into the version number of the reply.

usage: rewrite_proxy.py TARGET PAYLOAD
Prints its port on the first line of stdout, then serves until killed.

  GET  /v1/secret/data/...      .data.metadata.version  (kv get)
  GET  /v1/secret/metadata/...  .data.current_version   (kv metadata get)
  PUT/POST /v1/secret/data/...  .data.version           (write)
"""
import http.server
import json
import sys
import urllib.error as uerr
import urllib.request as ureq

target, payload = sys.argv[1], sys.argv[2]


class Handler(http.server.BaseHTTPRequestHandler):
    def _forward(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n) if n else None
        req = ureq.Request(target + self.path, data=body, method=self.command)
        for k, v in self.headers.items():
            if k.lower() not in ("host", "content-length"):
                req.add_header(k, v)
        try:
            r = ureq.urlopen(req)
            code, data = r.status, r.read()
        except uerr.HTTPError as e:
            code, data = e.code, e.read()
        if code == 200 and data:
            doc = json.loads(data)
            d = doc.get("data") or {}
            if self.path.startswith("/v1/secret/metadata/") and "current_version" in d:
                d["current_version"] = payload
            elif self.path.startswith("/v1/secret/data/"):
                if self.command == "GET" and "metadata" in d:
                    d["metadata"]["version"] = payload
                elif "version" in d:
                    d["version"] = payload
            data = json.dumps(doc).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = do_PUT = do_POST = do_DELETE = _forward

    def log_message(self, *args):
        pass


server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
print(server.server_port, flush=True)
server.serve_forever()
