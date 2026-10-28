#!/usr/bin/env bash
# Print the OTEL_ lines of the vault blob OMP_ENV (the Macs' ~/.omp/.env, secretspec project dotfiles): omp's
# trace export to Laminar, whose header line holds the project key. Every other line of the blob (the model
# API keys) stays on the Macs. Prints nothing and exits 0 when the blob has no OTEL_ line, so a caller can
# remove the VM's file. Run it where `secretspec get` reads the dotfiles project (SECRETSPEC_FILE set to the
# repo's secretspec.toml, and SECRETSPEC_REASON, see vm-sync-lib.sh).
# Exit 1 with a message that names the vault key and never a value; 2 on usage.
set -uo pipefail

if [ $# -ne 0 ]; then
  echo "usage: vm-laminar-env.sh" >&2
  exit 2
fi

die() {
  printf 'vm-laminar-env: %s\n' "$1" >&2
  exit 1
}

blob=$(secretspec get OMP_ENV) || die "cannot read OMP_ENV from the vault"
lines=$(printf '%s\n' "$blob" | LC_ALL=C grep -E '^OTEL_[A-Z0-9_]+=')
[ $? -le 1 ] || die "cannot read the OTEL_ lines of OMP_ENV"
[ -n "$lines" ] || exit 0
if printf '%s\n' "$lines" | LC_ALL=C grep -qvE '^OTEL_[A-Z0-9_]+=[[:print:]]*$'; then
  die "an OTEL_ line of OMP_ENV holds a CR, a tab or another control character: fix it on a Mac (~/.omp/.env), then just secretspec-sync --push OMP_ENV"
fi
printf '%s\n' "$lines"
