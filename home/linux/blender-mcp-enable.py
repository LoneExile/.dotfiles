"""Enable the MCP addon and return to Blender's event loop.

The socket server starts from a timer. That timer does not run in background
mode (blender -b), and a quit here would take the timer with it. A failed
enable exits 1 so the user service restarts instead of sitting idle.
"""
import addon_utils
import sys

try:
    mod = addon_utils.enable("blender_mcp", default_set=True, persistent=True)
except Exception as exc:
    print(f"blender-mcp: could not enable blender_mcp: {exc}", file=sys.stderr)
    raise SystemExit(1) from exc
if mod is None:
    print("blender-mcp: could not enable blender_mcp", file=sys.stderr)
    raise SystemExit(1)
