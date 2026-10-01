#!/usr/bin/env python3
"""A TCP listener for the tests that records whether anything connects.

usage: raw_listener.py OUTFILE SECONDS
Binds 127.0.0.1 on a free port and prints the port on the first line of stdout.
When a client connects it writes "CONNECTED" to OUTFILE, then the first line the
client sent ("CONNECT host:port ..." from an https proxy client, "GET http://..."
from an http one). It exits after SECONDS without a connection.
"""
import socket
import sys

out, seconds = sys.argv[1], float(sys.argv[2])
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 0))
s.listen(5)
print(s.getsockname()[1], flush=True)
s.settimeout(seconds)
try:
    c, _ = s.accept()
except OSError:
    sys.exit(0)
with open(out, "w") as f:
    f.write("CONNECTED\n")
c.settimeout(1)
try:
    first = c.recv(400).split(b"\r\n")[0].decode("latin1")
except OSError:
    first = "(connected, no data)"
with open(out, "a") as f:
    f.write(first + "\n")
