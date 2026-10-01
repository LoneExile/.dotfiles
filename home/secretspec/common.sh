# common.sh: small helpers shared by the secret-sync scripts. Sourced, not run.
# Works on bash 3.2 (/bin/bash) and with BSD or GNU coreutils.

die() {
  echo "error: $*" >&2
  exit 1
}

require_bins() {
  local b
  for b in bao jq; do
    command -v "$b" >/dev/null 2>&1 || die "$b not found on PATH (use dotfiles-secrets, or install openbao and jq)"
  done
}

# file_sha256 FILE: lowercase hex digest of the bytes.
file_sha256() {
  local out
  if command -v sha256sum >/dev/null 2>&1; then
    out=$(sha256sum <"$1") || return 1
  else
    out=$(shasum -a 256 <"$1") || return 1
  fi
  out=${out%% *}
  [[ $out =~ ^[0-9a-f]{64}$ ]] || return 1
  printf '%s\n' "$out"
}

# GNU stat first; BSD stat rejects -c.
file_mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
file_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }

# fmt_iso RFC3339-UTC: local "YYYY-MM-DD HH:MM". fmt_epoch EPOCH: same.
fmt_iso() {
  jq -rn --arg t "$1" '$t | sub("\\.[0-9]+"; "") | fromdateiso8601 | strflocaltime("%Y-%m-%d %H:%M")' 2>/dev/null || printf '%s' "$1"
}
fmt_epoch() {
  jq -rn --argjson t "$1" '$t | strflocaltime("%Y-%m-%d %H:%M")' 2>/dev/null || printf '%s' "$1"
}

# work_init: private scratch dir (0700) removed on exit. Value copies live here.
# A run killed with SIGKILL cannot remove its directory, so directories of this
# user older than a day are swept first; a younger one may belong to a run in
# progress and is left alone.
work_init() {
  # -H: /tmp is a symlink on macOS, and TMPDIR may be one too. The name is the
  # mktemp template below (six characters), so nothing else is touched.
  find -H "${TMPDIR:-/tmp}" -maxdepth 1 -type d -name 'dotfiles-secrets.??????' -user "$(id -un)" -mmin +1440 -exec rm -rf {} + 2>/dev/null || true
  WORK=$(umask 077 && mktemp -d "${TMPDIR:-/tmp}/dotfiles-secrets.XXXXXX") || die "cannot create a temp dir"
  trap 'rm -rf "$WORK"' EXIT
}

# Test seam: SECRETSPEC_TEST_CRASH_AT=<point> kills the run with SIGKILL there,
# so the tests can prove that a re-run converges. Call it only from the main
# flow, never inside a pipeline or $(...): it kills $$, the main shell.
crash_point() {
  if [[ ${SECRETSPEC_TEST_CRASH_AT:-} == "$1" ]]; then
    kill -9 $$
  fi
}
