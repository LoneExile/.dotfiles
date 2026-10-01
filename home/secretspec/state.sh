# state.sh: per-Mac sync records (spec §5.4). Sourced, not run.
# Needs common.sh and, for state_migrate, kv.sh.
#
# Layout under $XDG_STATE_HOME/dotfiles/secretspec (default ~/.local/state/...):
#   <NAME>.base.json  {"version": N, "sha256": HEX, "created_time": RFC3339}
#   last-contact      epoch seconds of the last run in which the vault answered every read
#   backup/<NAME>     one slot: the local bytes saved before "take vault"
#   <NAME>.sha256     legacy record of the old engine, removed by base_write
# The directory is 0700, files 0600, every write is tmp + rename.

CONTACT_MAX_AGE=$((7 * 86400))

# state_dir_init: set STATE_DIR without creating anything (status uses only this).
state_dir_init() {
  STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/secretspec
}

state_init() {
  state_dir_init
  mkdir -p "$STATE_DIR/backup"
  chmod 700 "$STATE_DIR" "$STATE_DIR/backup"
  rm -f "$STATE_DIR"/.tmp.* "$STATE_DIR"/backup/.tmp.*
}

# state_put DEST: replace DEST atomically with stdin, mode 0600. Call it with a
# redirect, not in a pipeline: crash_point kills $$, which must be the process
# doing the work.
state_put() {
  local dest=$1 tmp
  tmp=$(mktemp "$(dirname "$dest")/.tmp.XXXXXX") || die "cannot write under $STATE_DIR"
  if ! cat >"$tmp"; then
    rm -f "$tmp"
    die "cannot write $dest"
  fi
  chmod 600 "$tmp"
  sync "$tmp" || {
    rm -f "$tmp"
    die "cannot flush $dest to disk"
  }
  crash_point state-tmp-written
  mv -f "$tmp" "$dest"
}

# base_read NAME: sets B_VERSION B_SHA B_CT (empty when there is no usable
# record) and B_NOTE=corrupt when a file exists but cannot be used.
base_read() {
  local f=$STATE_DIR/$1.base.json fields=""
  B_VERSION="" B_SHA="" B_CT="" B_NOTE=""
  if [[ ! -f $f ]]; then
    return 0
  fi
  fields=$(jq -r 'if ((.version | type) == "number") and (.version >= 1) and (.version == (.version | floor))
      and ((.sha256 | type) == "string") and ((.created_time | type) == "string")
    then [(.version | tostring), .sha256, .created_time] | join("|") else empty end' "$f" 2>/dev/null) || fields=""
  if [[ -n $fields ]]; then
    IFS='|' read -r B_VERSION B_SHA B_CT <<<"$fields"
  fi
  if [[ ! $B_SHA =~ ^[0-9a-f]{64}$ ]]; then
    B_VERSION="" B_SHA="" B_CT="" B_NOTE=corrupt
  fi
}

# base_write NAME VERSION SHA CREATED_TIME: record, then drop the legacy file.
base_write() {
  jq -nc --argjson v "$2" --arg s "$3" --arg c "$4" \
    '{version: $v, sha256: $s, created_time: $c}' >"$WORK/base.new" || die "cannot build the record for $1"
  state_put "$STATE_DIR/$1.base.json" <"$WORK/base.new"
  crash_point base-written
  rm -f "$STATE_DIR/$1.sha256"
}

# base_legacy NAME: the old engine's hash, or nothing.
base_legacy() {
  local f=$STATE_DIR/$1.sha256 h
  if [[ ! -f $f ]]; then
    return 0
  fi
  h=$(tr -d ' \n' <"$f")
  if [[ $h =~ ^[0-9a-f]{64}$ ]]; then
    printf '%s\n' "$h"
  fi
}

# state_prune_legacy NAME: drop the legacy file once a usable base record exists.
state_prune_legacy() {
  base_read "$1"
  if [[ -n $B_VERSION ]]; then
    rm -f "$STATE_DIR/$1.sha256"
  fi
}

# state_migrate NAME CUR CUR_CT CUR_SHA COMMIT
# Turns the legacy hash into a base record: the newest retained version whose
# bytes hash to it. Returns 0 (B_* set; written when COMMIT=1), 1 (no legacy
# record, or no version matches; nothing changed), 2 (vault trouble, KV_CLASS
# says which; nothing changed).
state_migrate() {
  local name=$1 cur=$2 cur_ct=$3 cur_sha=$4 commit=$5 legacy v
  legacy=$(base_legacy "$name")
  B_VERSION="" B_SHA="" B_CT=""
  if [[ -z $legacy ]]; then
    return 1
  fi
  if [[ $legacy == "$cur_sha" ]]; then
    B_VERSION=$cur
    B_SHA=$cur_sha
    B_CT=$cur_ct
  else
    kv_meta "$name"
    if [[ $KV_CLASS != ok ]]; then
      return 2
    fi
    for v in $(kv_meta_live_versions); do
      if [[ $v -eq $cur ]]; then
        continue
      fi
      kv_read "$name" "$v"
      case $KV_CLASS in
        ok) ;;
        missing) continue ;;
        *) return 2 ;;
      esac
      if [[ $KV_SHA == "$legacy" ]]; then
        B_VERSION=$v
        B_SHA=$KV_SHA
        B_CT=$KV_CT
        break
      fi
    done
    if [[ -z $B_VERSION ]]; then
      return 1
    fi
  fi
  if [[ $commit == 1 ]]; then
    base_write "$name" "$B_VERSION" "$B_SHA" "$B_CT"
  fi
  return 0
}

contact_write() {
  date +%s >"$WORK/contact.new"
  state_put "$STATE_DIR/last-contact" <"$WORK/contact.new"
}

# contact_age: seconds since the last full contact; nothing when unknown or
# when the recorded time is in the future (that is no contact, and a negative
# age would pass the 7-day bound for ever).
contact_age() {
  local t now
  if [[ ! -f $STATE_DIR/last-contact ]]; then
    return 0
  fi
  t=$(tr -d ' \n' <"$STATE_DIR/last-contact")
  if [[ $t =~ ^[0-9]{1,15}$ ]]; then
    now=$(date +%s)
    if ((t <= now)); then
      echo $((now - t))
    fi
  fi
}

# contact_fresh: success when the last contact is at most 7 days old.
contact_fresh() {
  local age
  age=$(contact_age)
  [[ -n $age && $age -le $CONTACT_MAX_AGE ]]
}

# backup_put NAME FILE: the single backup slot for NAME. The slot is flushed and
# compared with FILE before this returns: after "take vault" or a merge it is the
# only copy of the user's bytes, and a failure here ends the run.
backup_put() {
  state_put "$STATE_DIR/backup/$1" <"$2"
  cmp -s "$2" "$STATE_DIR/backup/$1" || die "the backup of $1 does not match the file it was made from; nothing was changed after it"
}
