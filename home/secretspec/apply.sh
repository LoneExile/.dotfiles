# apply.sh: `apply`, the Home Manager activation step (spec §5.6). Sourced, not
# run. Needs the SECRETS table from materialize.sh and every other engine file.
#
# Pulls what is safe, records bases, prints one banner for everything that needs
# a human. It never prompts, never reads stdin and never writes the vault.

# Banner order, with what each state means.
ATTENTION_ORDER="ahead diverged rewound unknown vault-missing blocked changed offline"
attention_text() {
  case $1 in
    ahead) echo "local edits not in OpenBao" ;;
    diverged) echo "local and OpenBao both changed" ;;
    rewound) echo "OpenBao went back or was recreated" ;;
    unknown) echo "no record of a previous sync" ;;
    vault-missing) echo "not in OpenBao" ;;
    blocked) echo "not a regular file, left alone" ;;
    changed) echo "changed while it was being pulled, run again" ;;
    offline) echo "OpenBao is unreachable" ;;
  esac
}

# add_to LIST-NAME TEXT: append a line to a newline separated list variable.
add_to() {
  printf -v "$1" '%s%s\n' "${!1}" "$2"
}

apply_banner() { # ATTENTION-LIST
  local s st nm names only_offline=1 age
  echo >&2
  echo "!!!!!!!! secrets: needs attention !!!!!!!!" >&2
  for s in $ATTENTION_ORDER; do
    names=""
    while read -r st nm; do
      if [[ $st == "$s" ]]; then
        names="$names${names:+ }$nm"
      fi
    done <<<"$1"
    if [[ -z $names ]]; then
      continue
    fi
    if [[ $s == offline ]]; then
      age=$(contact_age)
      echo "  offline: OpenBao is unreachable ($VAULT_DOWN_ERR); kept the local files${age:+, last contact $((age / 3600)) h ago}" >&2
    else
      only_offline=0
      echo "  $s ($(attention_text "$s")): $names" >&2
    fi
  done
  if ((only_offline)); then
    echo "  → retry when OpenBao is reachable" >&2
  else
    echo "  → just secretspec-sync" >&2
  fi
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >&2
  echo >&2
}

cmd_apply() {
  umask 077
  local spec name rel mode dest rc answered=1 att="" fail="" auth="" auth_err="" offline_n=0 age line
  exec </dev/null
  require_bins
  work_init
  kv_init
  state_init
  ensure_layout
  for spec in "${SECRETS[@]}"; do
    IFS='|' read -r name rel mode <<<"$spec"
    dest=$HOME/$rel
    inspect "$name" "$dest" 1
    if [[ $D_CLASS != ok && $D_CLASS != missing ]]; then
      answered=0
    fi
    rc=0
    settle_auto "$name" "$dest" "$mode" || rc=$?
    case $rc in
      0) continue ;;
      2)
        add_to att "changed $name"
        continue
        ;;
    esac
    case $D_STATE in
      offline)
        offline_n=$((offline_n + 1))
        add_to att "offline $name"
        if [[ $D_LOCAL == absent ]]; then
          add_to fail "no local file for $name and OpenBao is unreachable"
        fi
        ;;
      auth-failed)
        auth="$auth${auth:+ }$name"
        auth_err=$I_ERR
        ;;
      vault-missing)
        add_to att "vault-missing $name"
        if [[ $D_LOCAL == absent ]]; then
          add_to fail "$name is missing from OpenBao and from this Mac"
        fi
        ;;
      *) add_to att "$D_STATE $name" ;;
    esac
  done
  if ((answered)); then
    contact_write
  fi
  if ((offline_n > 0)) && ! contact_fresh; then
    age=$(contact_age)
    if [[ -n $age ]]; then
      add_to fail "last contact with OpenBao was $((age / 86400)) days ago (the limit is 7 days)"
    else
      add_to fail "no successful contact with OpenBao is recorded (the limit is 7 days)"
    fi
  fi
  if [[ -n $auth ]]; then
    add_to fail "OpenBao refused the credentials for $auth ($auth_err). Fix: just openbao-login; for a certificate error, install the CA that signed it"
  fi
  if [[ -n $att ]]; then
    apply_banner "$att"
  fi
  if [[ -n $fail ]]; then
    while IFS= read -r line; do
      [[ -n $line ]] && echo "error: $line" >&2
    done <<<"$fail"
    exit 1
  fi
}
