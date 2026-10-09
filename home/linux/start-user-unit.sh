# shellcheck shell=bash
# start_user_unit SYSTEMCTL UNIT: start UNIT in the user manager of the user that runs this, when the manager knows it.
# Sourced by the Home Manager activation of home/linux/agent.nix, which supplies `run` (it prints instead of acting on a
# dry run). Used for rootless Docker: the NixOS switch only re-executes the user manager, so a user unit that the
# switch adds (WantedBy=default.target) stays stopped until the user manager starts again, at the next boot. Home Manager
# starts only its own units (sd-switch), so this step starts that one.
#   - No user manager yet, or no such unit: nothing to do, no output. At boot Home Manager runs before the user
#     manager exists, and the manager starts the unit itself then.
#   - Already active: `start` does nothing.
#   - The start fails: said on stderr, and the activation goes on. A broken daemon must not fail the whole switch.
start_user_unit() {
  local systemctl=$1 unit=$2 dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
  XDG_RUNTIME_DIR=$dir "$systemctl" --user cat "$unit" >/dev/null 2>&1 || return 0
  XDG_RUNTIME_DIR=$dir run "$systemctl" --user start "$unit" || printf 'start-user-unit: could not start %s (systemctl --user status %s)\n' "$unit" "$unit" >&2
  return 0
}
