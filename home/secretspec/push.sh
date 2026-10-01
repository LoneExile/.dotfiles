# push.sh: the only code that writes the vault (spec §5.9, "Push"). Sourced,
# not run. Needs common.sh kv.sh state.sh.

# push_local NAME DEST CAS REVIEWED_SHA
# Pushes the bytes of DEST, which must still hash to REVIEWED_SHA, with
# check-and-set CAS, reads them back and records the base.
# Returns 0 pushed, 1 refused or failed (the reason is printed), 2 check-and-set
# mismatch (the vault moved; decide again).
push_local() {
  local name=$1 dest=$2 cas=$3 reviewed=$4 copy=$WORK/push.$1 newv
  cp "$dest" "$copy"
  chmod 600 "$copy"
  if [[ $(file_sha256 "$copy") != "$reviewed" ]]; then
    echo "  $name changed while it was being reviewed; nothing pushed" >&2
    return 1
  fi
  if ! kv_pushable "$copy"; then
    echo "  refusing to push $name: the value is $KV_REFUSE" >&2
    return 1
  fi
  kv_write "$name" "$cas" "$copy"
  case $KV_CLASS in
    ok) ;;
    cas) return 2 ;;
    *)
      echo "  push of $name failed: $KV_ERR" >&2
      return 1
      ;;
  esac
  newv=$KV_NEWVERSION
  crash_point push-written
  kv_read "$name" "$newv"
  if [[ $KV_CLASS != ok ]] || ! cmp -s "$KV_VALUE" "$copy"; then
    echo "  ERROR: $name was written as v$newv but the read-back differs or failed (${KV_ERR:-bytes differ}); the base record was not updated" >&2
    return 1
  fi
  crash_point push-verified
  base_write "$name" "$newv" "$reviewed" "$KV_CT"
  if [[ $cas -eq 0 ]]; then
    echo "pushed $name - → v$newv"
  else
    echo "pushed $name v$cas → v$newv"
  fi
}
