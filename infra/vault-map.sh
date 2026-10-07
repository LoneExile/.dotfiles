# shellcheck shell=bash
# Helpers for the JSON-map secrets (VM_LUKS_KEYS, VM_INITRD_HOST_KEYS): one entry per VM name.
# Sourced by vm-install.sh, which defines die(). Needs secretspec and jq, and the environment
# secretspec needs (SECRETSPEC_FILE, SECRETSPEC_REASON).

# map_get KEY NAME: the string stored under NAME in the JSON map secret KEY, or nothing.
map_get() {
  secretspec get "$1" | jq -r --arg n "$2" '.[$n] // empty'
}

# map_put KEY NAME VALUE: read-modify-write of one entry. Each step finishes before the next
# starts, so a failed or empty read can never reach `secretspec set`, and the stored value
# stays untouched unless the new map is complete. The value reaches jq through its environment
# only, and jq's own stderr is dropped: its errors quote both operands, VALUE included.
# Run one vm-install at a time: two concurrent runs can overwrite each other's entry.
map_put() {
  local cur next
  cur=$(secretspec get "$1") || die "cannot read $1 from the vault"
  printf '%s' "$cur" | jq -e 'type == "object"' >/dev/null 2>&1 || die "$1 in the vault is not a JSON object (seed it with {})"
  next=$(printf '%s' "$cur" | MAP_NAME=$2 MAP_VALUE=$3 jq -c '. + {(env.MAP_NAME): env.MAP_VALUE}' 2>/dev/null) || die "cannot add the entry to $1"
  [ -n "$next" ] || die "the new $1 would be empty"
  printf '%s' "$next" | secretspec set "$1" >/dev/null || die "cannot write $1 to the vault"
  [ "$(map_get "$1" "$2")" = "$3" ] || die "could not store the entry in the vault key $1"
}
