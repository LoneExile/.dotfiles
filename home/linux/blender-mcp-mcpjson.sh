#!/bin/sh
# blender-mcp-mcpjson.sh DEST COMMAND
# Point mcpServers.blender at COMMAND. Every other server stays. Idempotent.
# DEST is the VM copy of ~/.omp/agent/mcp.json. COMMAND is the store wrapper,
# not a Mac path and not a bare uvx (omp on the VM does not inherit a login PATH).
set -eu
if [ $# -ne 2 ]; then
  echo "usage: blender-mcp-mcpjson.sh DEST COMMAND" >&2
  exit 2
fi
dest=$1
command=$2
if [ ! -f "$dest" ]; then
  echo "blender-mcp: $dest is missing; omp's config was not installed" >&2
  exit 1
fi
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
jq --arg cmd "$command" '
  .mcpServers.blender = {
    type: "stdio",
    command: $cmd,
    args: [],
    env: {
      BLENDER_HOST: "127.0.0.1",
      BLENDER_PORT: "9876",
      BLENDER_MCP_SAFE_MODE: "1",
      DISABLE_TELEMETRY: "true",
      SSL_CERT_FILE: "/etc/ssl/certs/ca-certificates.crt"
    }
  }
' "$dest" >"$tmp"
mv "$tmp" "$dest"
chmod u+w "$dest"
