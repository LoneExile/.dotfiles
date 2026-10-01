# decide.sh: the direction logic of spec §5.5. Sourced, not run. Pure: it reads
# D_* variables and two caller-supplied hooks, and writes D_ROW / D_STATE /
# D_NOTE. First matching row wins.
#
# Inputs
#   D_CLASS  ok | missing | hard | soft   transport result for the latest version
#   D_LOCAL  absent | regular | other     an empty local file counts as absent
#   D_LSHA   sha256 of the local file     D_VSHA  sha256 of the vault's bytes
#   D_CUR    current vault version        D_CT    its created_time
#   D_BV D_BSHA D_BCT   the base record (D_BV empty means no base)
# Hooks (called in the current shell, not in $(...); they may read the vault, and
# only run when local differs from the vault)
#   d_ct_at VERSION   set D_HOOK_CT to the created_time of a retained version,
#                     empty when it was pruned
#   d_stale MINVER    succeed when the local bytes equal a live retained version
#                     newer than MINVER
# Outputs
#   D_ROW    1a 1b 2 3 4 5 6 8 9 10 11 12
#   D_STATE  offline auth-failed vault-missing blocked missing-local in-sync
#            rewound behind stale ahead diverged unknown
#   D_NOTE   bad-record when row 7 made the base record be ignored, else empty

decide() {
  local has_base=0 min=0
  D_NOTE=""
  case $D_CLASS in
    soft)
      D_ROW=1a
      D_STATE=offline
      return 0
      ;;
    hard)
      D_ROW=1b
      D_STATE=auth-failed
      return 0
      ;;
    missing)
      D_ROW=2
      D_STATE=vault-missing
      return 0
      ;;
  esac
  if [[ $D_LOCAL == other ]]; then
    D_ROW=3
    D_STATE=blocked
    return 0
  fi
  if [[ $D_LOCAL == absent ]]; then
    D_ROW=4
    D_STATE=missing-local
    return 0
  fi
  if [[ $D_LSHA == "$D_VSHA" ]]; then
    D_ROW=5
    D_STATE=in-sync
    return 0
  fi
  if [[ -n $D_BV ]]; then
    has_base=1
    min=$D_BV
    # Row 6: the vault went backwards or was recreated since the base.
    if ((D_CUR < D_BV)); then
      D_ROW=6
      D_STATE=rewound
      return 0
    elif ((D_CUR == D_BV)); then
      if [[ $D_CT != "$D_BCT" ]]; then
        D_ROW=6
        D_STATE=rewound
        return 0
      fi
      # Row 7: same version, same epoch, other bytes: the record is wrong.
      if [[ $D_VSHA != "$D_BSHA" ]]; then
        has_base=0
        min=0
        D_NOTE=bad-record
      fi
    else
      d_ct_at "$D_BV"
      if [[ -n $D_HOOK_CT && $D_HOOK_CT != "$D_BCT" ]]; then
        D_ROW=6
        D_STATE=rewound
        return 0
      fi
    fi
  fi
  # Row 8: only the vault changed.
  if ((has_base)) && [[ $D_LSHA == "$D_BSHA" ]]; then
    D_ROW=8
    D_STATE=behind
    return 0
  fi
  # Row 9: local equals a newer retained vault version (a missed pull). Versions
  # at or below the base never count, so an edit back to an old value is an edit.
  if ((D_CUR > min)) && d_stale "$min"; then
    D_ROW=9
    D_STATE=stale
    return 0
  fi
  if ((!has_base)); then
    D_ROW=12
    D_STATE=unknown
    return 0
  fi
  if ((D_CUR == D_BV)); then
    D_ROW=10
    D_STATE=ahead
  else
    D_ROW=11
    D_STATE=diverged
  fi
}
