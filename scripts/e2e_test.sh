#!/usr/bin/env bash
# End-to-end check against a running RCodeBar listener on 127.0.0.1:47000.
#
# Usage:
#   scripts/e2e_test.sh <registered-host> [path]
#
# Requires RCodeBar running with <registered-host> already added in the app
# (Add via the popover first). Sends two requests:
#   1. a valid URI for <registered-host> -> expects "OK" and VS Code to open
#   2. a URI for a host guaranteed not registered -> expects "ERR unknown host"
#
# macOS ships bash 3.2 (no /dev/tcp support), so this uses python3 — already
# a hard requirement on the pod side and preinstalled on macOS.
set -euo pipefail

host="${1:?usage: e2e_test.sh <registered-host> [path]}"
path="${2:-$PWD}"

send() {
  local uri="$1"
  python3 - "$uri" <<'PY'
import socket, sys
uri = sys.argv[1]
s = socket.create_connection(("127.0.0.1", 47000), timeout=3)
s.sendall((uri + "\n").encode())
s.settimeout(3)
reply = b""
try:
    while not reply.endswith(b"\n"):
        chunk = s.recv(4096)
        if not chunk:
            break
        reply += chunk
except socket.timeout:
    pass
s.close()
print(reply.decode(errors="replace").strip())
PY
}

echo "== valid request: $host$path =="
reply=$(send "vscode://vscode-remote/ssh-remote+${host}${path}")
echo "reply: $reply"
if [ "$reply" != "OK" ]; then
  echo "FAIL: expected OK, got: $reply" >&2
  exit 1
fi
echo "PASS: got OK, check that VS Code opened $path on $host"

echo "== unknown host request =="
reply=$(send "vscode://vscode-remote/ssh-remote+__e2e_nonexistent_host__${path}")
echo "reply: $reply"
if [ "$reply" != "ERR unknown host" ]; then
  echo "FAIL: expected 'ERR unknown host', got: $reply" >&2
  exit 1
fi
echo "PASS: unknown host rejected"
