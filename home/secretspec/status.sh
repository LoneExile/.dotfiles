# status.sh: the read-only overview (spec §5.8). Sourced, not run.
# Needs the SECRETS table from materialize.sh plus common.sh kv.sh decide.sh
# state.sh inspect.sh. It writes nothing: no state directory, no migration, no
# last-contact record, no vault write.

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

# status_summary STATES: counts and the next command.
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
  echo "next: $next"
}

cmd_status() {
  local spec name rel mode dest states=""
  require_bins
  work_init
  kv_init
  state_dir_init
  printf '%-30s %-14s %-24s %-40s %s\n' NAME STATE LOCAL VAULT BASE
  for spec in "${SECRETS[@]}"; do
    IFS='|' read -r name rel mode _ <<<"$spec"
    dest=$HOME/$rel
    inspect "$name" "$dest" 0
    status_row
    states="$states$D_STATE"$'\n'
  done
  status_summary "$states"
}
