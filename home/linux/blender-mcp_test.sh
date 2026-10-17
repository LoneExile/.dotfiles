#!/usr/bin/env bash
# Tests for the agent VM's Blender MCP pieces: addon install, cage runner, and the
# mcp.json merge. No Blender, no network, no vault.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../secretspec/testlib.sh
. "$ROOT/home/secretspec/testlib.sh" || exit 1
# shellcheck source=minpath_testlib.sh
. "$ROOT/home/linux/minpath_testlib.sh" || exit 1
INSTALL=$ROOT/home/linux/blender-mcp-install.sh
RUN=$ROOT/home/linux/blender-mcp-run.sh
MERGE=$ROOT/home/linux/blender-mcp-mcpjson.sh
ENABLE=$ROOT/home/linux/blender-mcp-enable.py

fakes() {
  mkdir -p "$T/bin" "$T/home/blender"
  cat >"$T/bin/uvx" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$T/uvx.args"
printf '%s\n' "\${BLENDERMCP_ADDONS_DIR-}" >"$T/addons-dir"
printf '%s\n' "\${UV_PYTHON_PREFERENCE-}" >"$T/uv-pref"
exit 0
EOF
  cat >"$T/bin/cage" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >"$T/cage.args"
printf 'WLR=%s RENDER=%s EGL=%s DRI=%s DISPLAY=%s\n' "\${WLR_BACKENDS-}" "\${WLR_RENDERER-}" "\${__EGL_VENDOR_LIBRARY_FILENAMES-}" "\${LIBGL_DRIVERS_PATH-}" "\${DISPLAY-}" >"$T/cage.env"
while [ \$# -gt 0 ]; do
  if [ "\$1" = "--" ]; then
    shift
    break
  fi
  shift
done
exec "\$@"
EOF
  cat >"$T/bin/blender" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$T/blender.args"
printf 'DISPLAY=%s LIBGL=%s GALLIUM=%s SDL=%s\n' "\${DISPLAY-}" "\${LIBGL_ALWAYS_SOFTWARE-}" "\${GALLIUM_DRIVER-}" "\${SDL_AUDIODRIVER-}" >"$T/blender.env"
if [ "\${1-}" = "--help" ]; then
  printf '%s\n' "\$BLENDER_HELP"
  exit 0
fi
exit 0
EOF
  chmod +x "$T/bin/uvx" "$T/bin/cage" "$T/bin/blender"
}

run_install() {
  fakes
  env -i HOME="$T/home" PATH="$(minimal_path "$T/minbin")" SSL_CERT_FILE=/fixture/ca.crt \
    "$INSTALL" "$T/bin/uvx" 2.1.9 5.0 >"$T/out" 2>"$T/err"
  echo $?
}

run_blender() {
  fakes
  printf '%s\n' "$1" >"$T/help-text"
  env -i HOME="$T/home" PATH="$(minimal_path "$T/minbin")" BLENDER_HELP="$(cat "$T/help-text")" \
    DISPLAY=:99 \
    "$RUN" "$T/bin/cage" "$T/mesa" "$T/bin/blender" "$ENABLE" >"$T/out" 2>"$T/err"
  echo $?
}

test_install_pins_the_package_and_the_addons_dir() {
  assert_rc "install" "$(run_install)" 0
  assert_eq "uvx args" "--python 3.11 mcp-for-blender@2.1.9 install-addon" "$(cat "$T/uvx.args")"
  assert_eq "addons dir" "$T/home/.config/blender/5.0/scripts/addons" "$(cat "$T/addons-dir")"
  assert_eq "uv does not pick mise or nix python first" "only-managed" "$(cat "$T/uv-pref")"
  [ -d "$T/home/.config/blender/5.0/scripts/addons" ]
  assert_rc "addons dir exists" $? 0
}

test_runner_uses_headless_cage_and_never_background_mode() {
  assert_rc "run" "$(run_blender '--gpu-backend')" 0
  assert_eq "cage launches blender" "-- $T/bin/blender --gpu-backend opengl --python-exit-code 1 --python $ENABLE" "$(cat "$T/cage.args")"
  assert_eq "headless software compositor" "WLR=headless RENDER=pixman EGL=$T/mesa/share/glvnd/egl_vendor.d/50_mesa.json DRI=$T/mesa/lib/dri DISPLAY=" "$(cat "$T/cage.env")"
  assert_eq "stale X11 display is not passed to blender" "DISPLAY= LIBGL=1 GALLIUM=llvmpipe SDL=dummy" "$(cat "$T/blender.env")"
  assert_lacks "no background flag" "$T/blender.args" "--background"
  assert_lacks "no short background flag" "$T/blender.args" " -b"
}
test_runner_omits_gpu_backend_when_blender_has_no_such_flag() {
  assert_rc "run" "$(run_blender 'usage: blender')" 0
  assert_eq "no gpu flag" "-- $T/bin/blender --python-exit-code 1 --python $ENABLE" "$(cat "$T/cage.args")"
}

test_enable_script_does_not_quit_blender() {
  assert_lacks "no quit" "$ENABLE" "quit_blender"
  assert_has "enables the addon module" "$ENABLE" "blender_mcp"
  python3 -c 'import py_compile, sys; py_compile.compile(sys.argv[1], cfile=sys.argv[2])' "$ENABLE" "$T/enable.pyc"
  assert_rc "enable script parses" $? 0
}

test_mcpjson_merge_keeps_other_servers_and_is_idempotent() {
  fakes
  printf '%s\n' '{"mcpServers":{"codegraph":{"type":"stdio","command":"codegraph","args":["serve"]}}}' >"$T/mcp.json"
  env -i PATH="$(minimal_path "$T/minbin")" "$MERGE" "$T/mcp.json" /nix/store/abc-blender-mcp-server >"$T/out" 2>"$T/err"
  assert_rc "merge" $? 0
  assert_eq "other server stays" "codegraph" "$(jq -r '.mcpServers.codegraph.command' "$T/mcp.json")"
  assert_eq "command is the wrapper" "/nix/store/abc-blender-mcp-server" "$(jq -r '.mcpServers.blender.command' "$T/mcp.json")"
  assert_eq "localhost only" "127.0.0.1" "$(jq -r '.mcpServers.blender.env.BLENDER_HOST' "$T/mcp.json")"
  assert_eq "addon port" "9876" "$(jq -r '.mcpServers.blender.env.BLENDER_PORT' "$T/mcp.json")"
  assert_eq "safe mode" "1" "$(jq -r '.mcpServers.blender.env.BLENDER_MCP_SAFE_MODE' "$T/mcp.json")"
  assert_eq "telemetry off" "true" "$(jq -r '.mcpServers.blender.env.DISABLE_TELEMETRY' "$T/mcp.json")"
  before=$(shasum -a 256 "$T/mcp.json" | cut -c1-64)
  env -i PATH="$(minimal_path "$T/minbin")" "$MERGE" "$T/mcp.json" /nix/store/abc-blender-mcp-server
  assert_eq "second merge changes nothing" "$before" "$(shasum -a 256 "$T/mcp.json" | cut -c1-64)"
}

test_mcpjson_merge_refuses_a_missing_file() {
  fakes
  env -i PATH="$(minimal_path "$T/minbin")" "$MERGE" "$T/missing.json" /nix/store/abc-blender-mcp-server >"$T/out" 2>"$T/err"
  assert_rc "missing file" $? 1
  assert_has "says the file is missing" "$T/err" "missing"
}

tl_init_pure
tl_run_all
tl_done
