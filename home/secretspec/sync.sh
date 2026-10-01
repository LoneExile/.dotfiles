# sync.sh: `sync` and `sync --push NAME` (spec §5.7). Sourced, not run. Needs the
# SECRETS table and lookup_secret from materialize.sh plus every other engine
# file. Interactive; every decision that is not a safe pull is a human's.

SYNC_ERRORS=0
ANSWER=""

# ask PROMPT VALID DEFAULT: one letter from VALID into ANSWER. DEFAULT "" means
# there is no default: Enter asks again. End of input answers DEFAULT, or s.
ask() {
  local prompt=$1 valid=$2 default=${3:-} line
  while true; do
    printf '%s' "$prompt"
    if ! IFS= read -r line; then
      echo
      ANSWER=${default:-s}
      return 0
    fi
    line=$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')
    line=${line:0:1}
    if [[ -z $line && -n $default ]]; then
      ANSWER=$default
      return 0
    fi
    if [[ -n $line && $valid == *"$line"* ]]; then
      ANSWER=$line
      return 0
    fi
    echo "  answer one of: $valid"
  done
}

state_text() {
  case $1 in
    vault-missing) echo "OpenBao has no value" ;;
    blocked) echo "not a regular file" ;;
    rewound) echo "OpenBao went back or was recreated" ;;
    unknown) echo "no record of a previous sync" ;;
    ahead) echo "edited here, OpenBao unchanged" ;;
    diverged) echo "both sides changed" ;;
  esac
}

# take_vault NAME DEST MODE: keep the local bytes in the one backup slot, then pull.
take_vault() {
  if [[ $D_LOCAL == regular ]]; then
    backup_put "$1" "$2"
    echo "  your file is saved in $STATE_DIR/backup/$1"
  fi
  pull_file "$1" "$2" "$3" "$I_VALUE" "$D_LSHA" "$I_VERSION" "$I_CT" "$D_VSHA" || return 1
  echo "took vault $1 v$I_VERSION"
}

# sync_merge NAME DEST MODE: three windows in nvim (local editable, base and
# vault read-only) on temp copies. The merged copy is pushed first and only then
# saved over the local file. Returns 0 done, 1 error, 2 check-and-set mismatch
# (the local file is untouched), 3 nothing merged (ask again).
sync_merge() {
  local name=$1 dest=$2 mode=$3 d=$WORK/merge sha
  local -a views=(-c 'wincmd l' -c 'setlocal readonly nomodifiable')
  if ! command -v nvim >/dev/null 2>&1; then
    echo "  merging needs nvim"
    return 3
  fi
  mkdir -p "$d"
  chmod 700 "$d"
  cp "$dest" "$d/$name.local"
  cp "$I_VALUE" "$d/$name.vault"
  chmod 600 "$d/$name.local" "$d/$name.vault"
  if [[ -n $D_BV ]]; then
    kv_read "$name" "$D_BV"
    if [[ $KV_CLASS == ok ]]; then
      cp "$KV_VALUE" "$d/$name.base"
      chmod 600 "$d/$name.base"
      views=("${views[@]}" -c 'wincmd l' -c 'setlocal readonly nomodifiable')
    fi
  fi
  if [[ -f $d/$name.base ]]; then
    nvim --clean -n -d --cmd "$NVIM_SAFE" "${views[@]}" -c 'wincmd t' -- "$d/$name.local" "$d/$name.base" "$d/$name.vault" || true
  else
    nvim --clean -n -d --cmd "$NVIM_SAFE" "${views[@]}" -c 'wincmd t' -- "$d/$name.local" "$d/$name.vault" || true
  fi
  if cmp -s "$d/$name.local" "$dest"; then
    echo "  no changes made"
    return 3
  fi
  summary_masked "$name" "$d/$name.local" "$I_VALUE"
  ask "  push the merged file as v$((D_CUR + 1))? [y/N] " yn n
  if [[ $ANSWER != y ]]; then
    echo "  merge discarded, your file is unchanged"
    return 3
  fi
  sha=$(file_sha256 "$d/$name.local") || die "cannot hash the merged copy of $name"
  # Push first, install second: when the vault moved (return 2) or the push
  # fails, the local file is exactly what it was, and the one backup slot is
  # still free for the "take vault" that may follow.
  push_local "$name" "$d/$name.local" "$D_CUR" "$sha" || return $?
  backup_put "$name" "$dest"
  echo "  your file is saved in $STATE_DIR/backup/$name"
  install_file "$name" "$dest" "$mode" "$d/$name.local" "$D_LSHA" "$sha" || return 1
}

sync_ahead() {
  summary_masked "$1" "$2" "$I_VALUE"
  while true; do
    ask "  push $1 to OpenBao (v$D_CUR → v$((D_CUR + 1)))? [y/N/v] " ynv n
    case $ANSWER in
      v) show_raw_diff "$1" "$2" "$I_VALUE" ;;
      y)
        push_local "$1" "$2" "$D_CUR" "$D_LSHA"
        return $?
        ;;
      *)
        echo "  skipped"
        return 0
        ;;
    esac
  done
}

sync_diverged() {
  local rc
  summary_masked "$1" "$2" "$I_VALUE"
  while true; do
    ask "  [k]eep local and push / [t]ake vault / [m]erge / [s]kip: " ktms ""
    case $ANSWER in
      k)
        push_local "$1" "$2" "$D_CUR" "$D_LSHA"
        return $?
        ;;
      t)
        take_vault "$1" "$2" "$3"
        return $?
        ;;
      m)
        rc=0
        sync_merge "$1" "$2" "$3" || rc=$?
        if [[ $rc -ne 3 ]]; then return "$rc"; fi
        ;;
      s)
        echo "  skipped"
        return 0
        ;;
    esac
  done
}

sync_unknown() {
  summary_masked "$1" "$2" "$I_VALUE"
  ask "  [k]eep local and push / [t]ake vault / [s]kip: " kts ""
  case $ANSWER in
    k)
      push_local "$1" "$2" "$D_CUR" "$D_LSHA"
      return $?
      ;;
    t)
      take_vault "$1" "$2" "$3"
      return $?
      ;;
    *) echo "  skipped" ;;
  esac
}

sync_rewound() {
  echo "  OpenBao is at v$D_CUR; this Mac last synced v$D_BV"
  summary_masked "$1" "$2" "$I_VALUE"
  ask "  [r]estore OpenBao from the local file / [t]ake vault / [s]kip: " rts ""
  case $ANSWER in
    r)
      push_local "$1" "$2" "$D_CUR" "$D_LSHA"
      return $?
      ;;
    t)
      take_vault "$1" "$2" "$3"
      return $?
      ;;
    *) echo "  skipped" ;;
  esac
}

sync_vault_missing() {
  if [[ $D_LOCAL != regular ]]; then
    echo "  OpenBao has no value ($I_MISSING) and this Mac has no file: nothing to restore"
    return 0
  fi
  ask "  restore $1 in OpenBao from the local file ($I_MISSING)? [y/N] " yn n
  if [[ $ANSWER == y ]]; then
    push_local "$1" "$2" "$I_VERSION" "$D_LSHA"
    return $?
  fi
  echo "  skipped"
}

# sync_review NAME: decide again from scratch, handle the safe states, ask about
# the rest. A check-and-set mismatch starts over with fresh facts.
sync_review() {
  local name=$1 dest mode rc
  lookup_secret "$name"
  dest=$HOME/$S_REL
  mode=$S_MODE
  while true; do
    inspect "$name" "$dest" 1
    rc=0
    settle_auto "$name" "$dest" "$mode" || rc=$?
    if [[ $rc -ne 1 ]]; then return 0; fi
    echo
    echo "== $name: $D_STATE ($(state_text "$D_STATE"))"
    rc=0
    case $D_STATE in
      vault-missing) sync_vault_missing "$name" "$dest" || rc=$? ;;
      blocked) echo "  $dest is not a regular file (symlink, directory or other); left alone" ;;
      rewound) sync_rewound "$name" "$dest" "$mode" || rc=$? ;;
      unknown) sync_unknown "$name" "$dest" "$mode" || rc=$? ;;
      ahead) sync_ahead "$name" "$dest" || rc=$? ;;
      diverged) sync_diverged "$name" "$dest" "$mode" || rc=$? ;;
      *) die "$name: $D_STATE: ${I_ERR:-unexpected state}" ;;
    esac
    if [[ $rc -eq 2 ]]; then
      echo "  OpenBao changed while you were deciding (check-and-set); looking again"
      continue
    fi
    if [[ $rc -ne 0 ]]; then SYNC_ERRORS=$((SYNC_ERRORS + 1)); fi
    return 0
  done
}

# sync_push_one NAME: non-interactive keep-local for one secret.
sync_push_one() {
  local name=$1 dest rc=0
  lookup_secret "$name"
  dest=$HOME/$S_REL
  inspect "$name" "$dest" 1
  case $D_STATE in
    ahead | diverged | unknown | rewound)
      push_local "$name" "$dest" "$D_CUR" "$D_LSHA" || rc=$?
      ;;
    vault-missing)
      if [[ $D_LOCAL != regular ]]; then die "$name: no local file to push"; fi
      push_local "$name" "$dest" "$I_VERSION" "$D_LSHA" || rc=$?
      ;;
    offline | auth-failed) die "$name: OpenBao: $I_ERR" ;;
    *) die "refusing to push $name: it is $D_STATE (--push needs ahead, diverged, unknown, rewound or vault-missing)" ;;
  esac
  if [[ $rc -eq 2 ]]; then die "$name: OpenBao changed while pushing (check-and-set); run: just secretspec-status"; fi
  if [[ $rc -ne 0 ]]; then exit 1; fi
}

cmd_sync() {
  umask 077
  local line state name
  local -a todo=()
  case ${1:-} in
    "") ;;
    --push)
      if [[ -z ${2:-} || $# -ne 2 ]]; then die "usage: sync --push NAME"; fi
      ;;
    *) die "usage: sync [--push NAME]" ;;
  esac
  require_bins
  work_init
  kv_init
  state_init
  ensure_layout
  if [[ ${1:-} == --push ]]; then
    sync_push_one "$2"
    return 0
  fi
  if [[ ! -t 0 || ! -t 1 ]]; then
    die "sync needs a terminal; for one secret use: sync --push NAME"
  fi
  status_table 1
  status_summary "$(awk '{ print $1 }' <<<"$STATUS_LIST")" quiet
  if grep -q '^offline ' <<<"$STATUS_LIST"; then
    die "OpenBao is unreachable: $VAULT_DOWN_ERR"
  fi
  if grep -q '^auth-failed ' <<<"$STATUS_LIST"; then
    die "OpenBao refused the credentials; run: just openbao-login"
  fi
  echo
  while read -r state name; do
    [[ -n $name ]] || continue
    todo=(${todo[@]+"${todo[@]}"} "$state:$name")
  done <<<"$STATUS_LIST"
  for line in ${todo[@]+"${todo[@]}"}; do
    case ${line%%:*} in
      missing-local | behind | stale | in-sync) sync_review "${line#*:}" ;;
    esac
  done
  for line in ${todo[@]+"${todo[@]}"}; do
    case ${line%%:*} in
      vault-missing | blocked | rewound | unknown | ahead | diverged) sync_review "${line#*:}" ;;
    esac
  done
  if [[ $SYNC_ERRORS -gt 0 ]]; then
    echo
    die "$SYNC_ERRORS secret(s) failed, see above"
  fi
}
