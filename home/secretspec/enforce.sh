# enforce.sh: `enforce-cas` (spec D8, §5.10). Sourced, not run. Needs the SECRETS
# table from materialize.sh plus common.sh and kv.sh.
#
# Makes OpenBao refuse any write to the secrets' paths that carries no
# check-and-set (cas_required=true). Run it once, after every Mac runs this
# engine: an older engine, and the secretspec CLI's own writes, carry none.

cmd_enforce_cas() {
  umask 077
  local spec name failed=0 on
  require_bins
  work_init
  kv_init
  for spec in "${SECRETS[@]}"; do
    IFS='|' read -r name _ <<<"$spec"
    kv_enforce_cas "$name"
    case $KV_CLASS in
      ok)
        kv_meta_reset
        kv_meta "$name"
        on=""
        if [[ $KV_CLASS == ok ]]; then
          on=$(jq -r '.data.cas_required' "$KV_META_FILE")
        fi
        if [[ $on == true ]]; then
          echo "cas_required $name"
        else
          echo "error: $name: cas_required is not set after the patch" >&2
          failed=$((failed + 1))
        fi
        ;;
      missing)
        echo "error: $name: no such path in OpenBao" >&2
        failed=$((failed + 1))
        ;;
      hard)
        echo "error: $name: $KV_ERR (the token needs the patch capability on secret/metadata/$KV_PREFIX/*)" >&2
        failed=$((failed + 1))
        ;;
      *) die "OpenBao is unreachable: $KV_ERR" ;;
    esac
  done
  if ((failed > 0)); then
    die "$failed of ${#SECRETS[@]} paths are not enforced"
  fi
  echo "OpenBao now rejects writes without check-and-set to all ${#SECRETS[@]} secrets"
}
