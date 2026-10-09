#!/usr/bin/env bash
# Fail when a git-tracked file holds an identifying server value from TF_VAR_*,
# the S3 endpoint host (TF_STATE_S3_ENDPOINT), the S3 secret key (AWS_SECRET_ACCESS_KEY)
# or a LUKS passphrase (VM_LUKS_KEYS, a JSON map of VM name to passphrase), or a GitHub token
# (VM_GH_TOKENS, a JSON map of VM name to token; optional: unset, empty or {} means none yet).
# Skipped on purpose: the other TF_VAR_* values (datastores, bridge, node, sizing: generic),
# TF_STATE_S3_BUCKET (generic, like datastores), AWS_ACCESS_KEY_ID (its value equals the
# public project name and it cannot authenticate without the secret key) and
# VM_INITRD_HOST_KEYS (public keys, not secrets).
# Exit: 0 clean, 1 leak, 2 missing env or value shorter than 4 characters,
# 3 positive control failed or grep error. Never prints a value.
set -uo pipefail
set +x
umask 077

die() { # die CODE MESSAGE
  printf 'infra-leak-check: %s\n' "$2" >&2
  exit "$1"
}

for var in TF_VAR_proxmox_endpoint TF_VAR_proxmox_api_token TF_VAR_tofu_state_passphrase TF_VAR_vms TF_STATE_S3_ENDPOINT AWS_SECRET_ACCESS_KEY VM_LUKS_KEYS; do
  [[ -n ${!var:-} ]] || die 2 "missing environment variable $var"
done

work=$(mktemp -d "${TMPDIR:-/tmp}/infra-leak-check.XXXXXX") || die 3 "cannot create temp dir"
trap 'rm -rf "$work"' EXIT
raw=$work/raw
patterns=$work/patterns
: >"$raw"

# add LABEL VALUE: queue a value; abort naming the label when it is too short.
add() {
  [[ ${#2} -ge 4 ]] || die 2 "$1 is shorter than 4 characters"
  printf '%s\n' "$2" >>"$raw"
}

# endpoint_host URL: strip scheme, path and port.
endpoint_host() {
  local h=${1#*://}
  h=${h%%/*}
  printf '%s' "${h%:*}"
}
add "proxmox endpoint host" "$(endpoint_host "$TF_VAR_proxmox_endpoint")"
add "s3 endpoint host" "$(endpoint_host "$TF_STATE_S3_ENDPOINT")"
add "s3 secret key" "$AWS_SECRET_ACCESS_KEY"
token=$TF_VAR_proxmox_api_token
add "proxmox token id" "${token%%=*}"
secret=""
[[ $token == *=* ]] && secret=${token#*=}
add "proxmox token secret" "$secret"
add "state passphrase" "$TF_VAR_tofu_state_passphrase"

vmfields=$work/vmfields
printf '%s' "$TF_VAR_vms" | jq -r 'to_entries[] | .key, ((.value.ipv4_cidr // "") | split("/")[0]), (.value.mac // ""), (.value.gateway // "")' >"$vmfields" 2>/dev/null ||
  die 2 "TF_VAR_vms is not valid JSON of the expected shape"
labels=("vm name" "vm ipv4" "vm mac" "vm gateway")
i=0
while IFS= read -r line; do
  add "${labels[$((i % 4))]}" "$line"
  i=$((i + 1))
done <"$vmfields"

# VM_LUKS_KEYS: JSON object, VM name -> LUKS passphrase of its root disk. Every value is a pattern.
# `{}` is valid (no VM installed yet). The VM names are covered by TF_VAR_vms above.
lukslist=$work/luks
printf '%s' "$VM_LUKS_KEYS" | jq -r 'if type == "object" then .[] | if type == "string" then . else error("not a string") end else error("not an object") end' >"$lukslist" 2>/dev/null ||
  die 2 "VM_LUKS_KEYS is not a JSON object of strings"
while IFS= read -r line; do
  add "luks passphrase" "$line"
done <"$lukslist"

# VM_GH_TOKENS: optional JSON object, VM name -> GitHub token of that VM. Every non-empty value is
# a pattern; an entry with an empty value counts as no entry (vm-sync skips it the same way).
gh_map=${VM_GH_TOKENS:-}
[[ -n $gh_map ]] || gh_map='{}'
ghlist=$work/gh
printf '%s' "$gh_map" | jq -r 'if type == "object" then .[] | if type == "string" then select(length > 0) else error("not a string") end else error("not an object") end' >"$ghlist" 2>/dev/null ||
  die 2 "VM_GH_TOKENS is not a JSON object of strings"
while IFS= read -r line; do
  add "github token" "$line"
done <"$ghlist"

sort -u "$raw" >"$patterns"
nvalues=$(wc -l <"$patterns" | tr -d ' ')

root=$(git rev-parse --show-toplevel 2>/dev/null) || die 3 "not inside a git repository"
cd "$root" || die 3 "cannot enter repository root"

hits=$work/hits
gerr=$work/gerr
nfiles=$(git ls-files -z | tr -cd '\0' | wc -c | tr -d ' ')
: >"$hits"
: >"$gerr"
if [[ $nfiles -gt 0 ]]; then
  git ls-files -z | xargs -0 grep -IlwiF -f "$patterns" -- >"$hits" 2>"$gerr"
fi
[[ -s $gerr ]] && die 3 "grep reported an error"

# Positive control: the first pattern must hit a file that holds it.
head -n 1 "$patterns" >"$work/control"
ctl_hits=$(grep -IlwiF -f "$patterns" -- "$work/control" 2>"$work/cerr")
if [[ -s $work/cerr ]] || [[ -z $ctl_hits ]]; then
  die 3 "positive control failed"
fi

if [[ -s $hits ]]; then
  while IFS= read -r path; do
    printf 'infra-leak-check: LEAK in %s\n' "$path"
  done <"$hits"
  exit 1
fi
printf 'infra-leak-check: %s values, %s tracked files, no leaks\n' "$nvalues" "$nfiles"
