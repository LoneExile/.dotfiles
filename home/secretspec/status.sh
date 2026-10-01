# status.sh: the read-only overview (spec §5.8). Sourced, not run.
# Needs the SECRETS table from materialize.sh plus common.sh kv.sh decide.sh
# state.sh inspect.sh. cmd_status writes nothing: no state directory, no
# migration, no last-contact record, no vault write. status_table with COMMIT=1
# (used by sync) does write bases and migrates legacy records.

# Order of the states in the summary line.
STATUS_ORDER="in-sync behind stale missing-local ahead diverged rewound unknown vault-missing blocked offline auth-failed"

# status_row: print one line for the secret just inspected.
status_row() {
  local localcol vaultcol basecol=""
  case $D_LOCAL in
    absent) localcol=absent ;;
    other) localcol="not a file" ;;
    *)
      if [[ -n $D_BV && $D_LSHA == "$D_BSHA" ]]; then
        localcol="= v$D_BV"
      elif [[ $D_CLASS == ok && $D_LSHA == "$D_VSHA" ]]; then
        localcol="= v$D_CUR"
      else
        localcol="edited $(fmt_epoch "$I_LMTIME")"
      fi
      ;;
  esac
  case $D_CLASS in
    ok) vaultcol="v$I_VERSION $(fmt_iso "$I_CT") ${I_WRITER:-?}" ;;
    missing) vaultcol="missing ($I_MISSING)" ;;
    soft) vaultcol="unreachable: $I_ERR" ;;
    hard) vaultcol="refused: $I_ERR" ;;
  esac
  if [[ -n $D_BV ]]; then
    if [[ $D_BV != "$D_CUR" ]]; then
      basecol="base v$D_BV"
    fi
  elif [[ $D_LOCAL == regular && $D_CLASS == ok && $D_STATE != in-sync ]]; then
    basecol="no base"
  fi
  printf '%-30s %-14s %-24s %-40s %s\n' "$I_NAME" "$D_STATE" "$localcol" "$vaultcol" "$basecol"
}

# status_summary STATES [quiet]: counts and, unless quiet, the next command.
status_summary() {
  local states=$1 s n total=0 parts="" next
  for s in $STATUS_ORDER; do
    n=$(grep -cx "$s" <<<"$states" || true)
    if [[ $n -gt 0 ]]; then
      parts="$parts${parts:+, }$n $s"
    fi
    total=$((total + n))
  done
  next="nothing to do"
  if grep -qxE 'missing-local|behind|stale' <<<"$states"; then
    next="just home"
  fi
  if grep -qxE 'vault-missing|blocked|rewound|ahead|diverged|unknown' <<<"$states"; then
    next="just secretspec-sync"
  fi
  if grep -qx offline <<<"$states"; then
    next="retry when OpenBao is reachable"
  fi
  if grep -qx auth-failed <<<"$states"; then
    next="just openbao-login"
  fi
  echo
  echo "$total secrets: $parts"
  if [[ ${2:-} != quiet ]]; then
    echo "next: $next"
  fi
}

# status_table COMMIT: header and one row per secret. Sets STATUS_LIST ("STATE
# NAME" per line). COMMIT=1 (sync) may migrate legacy records and records the
# base of in-sync secrets as it goes; COMMIT=0 changes nothing.
status_table() {
  local commit=$1 spec name rel mode dest
  STATUS_LIST=""
  printf '%-30s %-14s %-24s %-40s %s\n' NAME STATE LOCAL VAULT BASE
  for spec in "${SECRETS[@]}"; do
    IFS='|' read -r name rel mode <<<"$spec"
    dest=$HOME/$rel
    inspect "$name" "$dest" "$commit"
    status_row
    STATUS_LIST="$STATUS_LIST$D_STATE $name"$'\n'
    if [[ $commit == 1 && $D_STATE == in-sync ]]; then
      settle_auto "$name" "$dest" "$mode"
    fi
  done
}

cmd_status() {
  umask 077
  require_bins
  work_init
  kv_init
  state_dir_init
  status_table 0
  status_summary "$(awk '{ print $1 }' <<<"$STATUS_LIST")"
}
