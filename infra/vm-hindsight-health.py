#!/usr/bin/env python3
"""Check that the Hindsight gate accepts a key, before vm-sync pushes that key to a VM.

Reads two lines on stdin, the Hindsight URL and then the API key, and sends
GET <url>/health with the header "Authorization: Bearer <key>". Exit 0 when the gate
answers 200; exit 1 with a message (the status or the kind of error, never the URL or the
key) otherwise; exit 2 on a usage or shape error, before anything is sent.

The key goes out only over verified TLS (python's default trust store), never through a
proxy of the environment, and a redirect is not followed (it would carry the key to another
address). No arguments: the URL and the key never stand on a command line.
"""
import re
import sys
import urllib.error
import urllib.request

URL_RE = r"https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?(/[A-Za-z0-9._/-]*)?"
KEY_RE = r"[A-Za-z0-9_-]{20,255}"


def die(code, message):
    print("vm-hindsight-health: " + message, file=sys.stderr)
    sys.exit(code)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def main():
    if len(sys.argv) != 1:
        die(2, "takes no arguments: the URL and the key come on stdin")
    lines = sys.stdin.read().split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    if len(lines) != 2:
        die(2, "stdin must be two lines: the URL, then the key")
    url, key = lines
    if not re.fullmatch(URL_RE, url):
        die(2, "the URL on stdin is not an https URL of the usual shape")
    if not re.fullmatch(KEY_RE, key):
        die(2, "the key on stdin has an unexpected shape")

    request = urllib.request.Request(
        url.rstrip("/") + "/health",
        headers={"Authorization": "Bearer " + key, "User-Agent": "dotfiles-vm-sync/1"},
    )
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({}), NoRedirect, urllib.request.HTTPSHandler()
    )
    try:
        with opener.open(request, timeout=15) as response:
            status = response.status
    except urllib.error.HTTPError as error:
        status = error.code
    except Exception as error:  # noqa: BLE001 - the kind is all we say
        kind = type(getattr(error, "reason", error)).__name__
        die(1, "could not reach the Hindsight gate (%s)" % kind)
    if status != 200:
        die(1, "the Hindsight gate answered HTTP %d instead of 200 (is the key revoked or wrong?)" % status)
    print("hindsight: the gate accepts the key (HTTP 200)")


if __name__ == "__main__":
    main()
