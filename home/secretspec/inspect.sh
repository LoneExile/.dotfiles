# inspect.sh: gather local, vault and base state for one secret and run decide().
# Sourced, not run. Needs common.sh kv.sh decide.sh state.sh.
#
# inspect NAME DEST COMMIT
#   COMMIT=1 (apply, sync) may migrate a legacy record and prune its file.
#   COMMIT=0 (status) changes nothing on disk.
# Sets the D_* inputs, D_ROW / D_STATE / D_NOTE, and
#   I_NAME I_DEST   the arguments
#   I_VALUE         file holding the vault's latest bytes (D_CLASS ok only)
#   I_VERSION I_CT I_WRITER   of the latest vault version
#   I_MISSING       absent | deleted | destroyed | empty | no-value (D_CLASS missing)
#   I_ERR           cause of a soft or hard failure
#   I_LMTIME        local mtime (epoch)
#   I_STALE_VERSION the version row 9 matched
# VAULT_DOWN is the circuit breaker: after the first soft error of a run no
# further vault call is made and every remaining secret is offline.

VAULT_DOWN=""
VAULT_DOWN_ERR=""

# hook_fail: a vault call inside a decide() hook failed; decide again as 1a/1b.
hook_fail() {
  I_HOOKFAIL=$KV_CLASS
  I_ERR=$KV_ERR
  if [[ $KV_CLASS == soft ]]; then
    VAULT_DOWN=soft
    VAULT_DOWN_ERR=$KV_ERR
  fi
}

d_ct_at() {
  D_HOOK_CT=""
  kv_meta "$I_NAME"
  if [[ $KV_CLASS != ok ]]; then
    hook_fail
    return 0
  fi
  D_HOOK_CT=$(kv_meta_ct "$1")
}

d_stale() {
  local v
  kv_meta "$I_NAME"
  if [[ $KV_CLASS != ok ]]; then
    hook_fail
    return 1
  fi
  for v in $(kv_meta_live_versions); do
    if [[ $v -le $1 ]]; then
      break
    fi
    if [[ $v -eq $D_CUR ]]; then
      continue
    fi
    kv_read "$I_NAME" "$v"
    case $KV_CLASS in
      ok) ;;
      missing) continue ;;
      *)
        hook_fail
        return 1
        ;;
    esac
    if [[ $KV_SHA == "$D_LSHA" ]]; then
      I_STALE_VERSION=$v
      return 0
    fi
  done
  return 1
}

inspect() {
  local name=$1 dest=$2 commit=$3 mig=0
  I_NAME=$name I_DEST=$dest I_VALUE="" I_VERSION=0 I_CT="" I_WRITER="" I_ERR="" I_MISSING=""
  I_LMTIME="" I_STALE_VERSION="" I_HOOKFAIL=""
  D_LOCAL=absent D_LSHA="" D_CLASS=ok D_CUR=0 D_CT="" D_VSHA="" D_BV="" D_BSHA="" D_BCT=""
  kv_meta_reset

  # Local file. An empty file counts as absent.
  if [[ -L $dest ]] || { [[ -e $dest ]] && [[ ! -f $dest ]]; }; then
    D_LOCAL=other
  elif [[ -s $dest ]]; then
    D_LOCAL=regular
    D_LSHA=$(file_sha256 "$dest") || die "cannot hash $dest"
    I_LMTIME=$(file_mtime "$dest")
  fi

  # Vault.
  if [[ -n $VAULT_DOWN ]]; then
    D_CLASS=$VAULT_DOWN
    I_ERR=$VAULT_DOWN_ERR
  else
    kv_read "$name"
    D_CLASS=$KV_CLASS
    I_ERR=$KV_ERR
    I_VERSION=$KV_VERSION
    case $KV_CLASS in
      ok)
        I_VALUE=$KV_VALUE
        I_CT=$KV_CT
        I_WRITER=$KV_WRITER
        D_CUR=$KV_VERSION
        D_CT=$KV_CT
        D_VSHA=$KV_SHA
        ;;
      missing)
        I_MISSING=$KV_MISSING
        I_CT=$KV_CT
        ;;
      soft)
        VAULT_DOWN=soft
        VAULT_DOWN_ERR=$KV_ERR
        ;;
    esac
  fi

  # Base record; a legacy hash becomes one when the sides differ.
  base_read "$name"
  D_BV=$B_VERSION D_BSHA=$B_SHA D_BCT=$B_CT
  if [[ -n $D_BV ]]; then
    if [[ $commit == 1 ]]; then
      state_prune_legacy "$name"
    fi
  elif [[ $D_CLASS == ok && $D_LOCAL == regular && $D_LSHA != "$D_VSHA" && -n $(base_legacy "$name") ]]; then
    state_migrate "$name" "$D_CUR" "$D_CT" "$D_VSHA" "$commit" || mig=$?
    case $mig in
      0) D_BV=$B_VERSION D_BSHA=$B_SHA D_BCT=$B_CT ;;
      2) hook_fail ;;
    esac
  fi

  decide
  if [[ -n $I_HOOKFAIL ]]; then
    D_CLASS=$I_HOOKFAIL
    decide
  fi
}
