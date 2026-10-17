#!/bin/sh
# Install the MCP for Blender addon into this user's Blender scripts directory.
# Args: UVX VERSION MAJOR_MINOR
# UVX is the uvx binary. VERSION is the PyPI pin (mcp-for-blender@VERSION).
# MAJOR_MINOR is Blender's config directory name (5.0 for Blender 5.0.1).
# The first run downloads the package; SSL_CERT_FILE must be set (the unit sets it).
set -eu
if [ $# -ne 3 ]; then
  echo "usage: blender-mcp-install.sh UVX VERSION MAJOR_MINOR" >&2
  exit 2
fi
uvx="$1"
version="$2"
minor="$3"
dir="${HOME:?}/.config/blender/${minor}/scripts/addons"
mkdir -p "$dir"
export BLENDERMCP_ADDONS_DIR="$dir"
export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}"
export UV_PYTHON_PREFERENCE="${UV_PYTHON_PREFERENCE:-only-managed}"
exec "$uvx" --python 3.11 "mcp-for-blender@${version}" install-addon
