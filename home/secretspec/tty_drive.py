#!/usr/bin/env python3
"""Run a command on a pseudo-terminal with its answers typed ahead.

usage: tty_drive.py ANSWERS_FILE TIMEOUT_SECONDS CMD [ARG...]

Every byte of ANSWERS_FILE is queued on the terminal before the command reads
anything (newline becomes the Enter key). The terminal transcript, with CR
removed, goes to stdout. Exit status: the command's, or 124 after the timeout.
`script -q /dev/null` is not used: on macOS it injects an EOF character ahead of
the queued input and the first read comes back empty.
"""
import os
import pty
import select
import signal
import sys
import time

answers = open(sys.argv[1], "rb").read()
deadline = time.time() + float(sys.argv[2])
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[3], sys.argv[3:])
os.write(fd, answers.replace(b"\n", b"\r"))
out = bytearray()
status = None
while True:
    left = deadline - time.time()
    if left <= 0:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
        status = 124
        break
    ready, _, _ = select.select([fd], [], [], min(left, 0.2))
    if ready:
        try:
            data = os.read(fd, 65536)
        except OSError:
            data = b""
        if not data:
            break
        out += data
if status is None:
    status = os.waitstatus_to_exitcode(os.waitpid(pid, 0)[1])
sys.stdout.buffer.write(bytes(out).replace(b"\r\n", b"\n").replace(b"\r", b""))
sys.exit(status)
