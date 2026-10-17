#!/bin/sh
# Run Blender under a headless Wayland compositor so the MCP addon can start
# its socket server. The NixOS Xvfb build has no GLX module, so Blender cannot
# open a window there. cage's headless backend plus Mesa llvmpipe can.
# blender -b is refused by the addon: commands would never execute.
# Args: CAGE MESA BLENDER ENABLE_PY
set -eu
if [ $# -ne 4 ]; then
  echo "usage: blender-mcp-run.sh CAGE MESA BLENDER ENABLE_PY" >&2
  exit 2
fi
cage="$1"
mesa="$2"
blender="$3"
enable="$4"
mkdir -p "${HOME:?}/blender"
cd "$HOME/blender"

# A stale DISPLAY makes Blender try X11. These VMs have no GLX.
unset DISPLAY
unset WAYLAND_DISPLAY

export WLR_BACKENDS=headless
export WLR_RENDERER=pixman
export WLR_HEADLESS_OUTPUTS=1
export WLR_LIBINPUT_NO_DEVICES=1
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export LIBGL_DRIVERS_PATH="$mesa/lib/dri"
export __EGL_VENDOR_LIBRARY_FILENAMES="$mesa/share/glvnd/egl_vendor.d/50_mesa.json"
export SDL_AUDIODRIVER=dummy

if "$blender" --help 2>/dev/null | grep -q -- '--gpu-backend'; then
  exec "$cage" -- "$blender" --gpu-backend opengl --python-exit-code 1 --python "$enable"
fi
exec "$cage" -- "$blender" --python-exit-code 1 --python "$enable"
