# kv.sh: OpenBao KV v2 transport for the secret-sync scripts. Sourced, not run.
# Needs common.sh (file_sha256, WORK) plus the bao and jq binaries.
#
# Every vault call goes through kv_bao, which clears each BAO_* / VAULT_*
# variable of the caller and every proxy variable (HTTP_PROXY, HTTPS_PROXY,
# ALL_PROXY, NO_PROXY, in both cases: bao would send the call, and for http the
# token, wherever they point), then sets only the address, token and timeout
# resolved by kv_init. Secret values travel in files and on stdin, never in
# argv or in shell variables.
#
# Results are left in globals:
#   KV_CLASS    ok | missing | hard | soft | cas
#   KV_ERR      one-line cause when KV_CLASS is not ok
#   KV_VERSION KV_CT KV_WRITER KV_VALUE KV_SHA   (kv_read, class ok)
#   KV_MISSING  absent | deleted | destroyed | empty | no-value   (class missing)

KV_MOUNT=secret
KV_PREFIX=secretspec/dotfiles/default
KV_META_NAME=""

# kv_init: address and token, once per run. VAULT_TOKEN wins over the token file.
kv_init() {
  KV_ADDR=${SECRETSPEC_SYNC_ADDR:-https://openbao.home.0dl.me}
  KV_TIMEOUT=${SECRETSPEC_SYNC_TIMEOUT:-10s}
  KV_TOKEN=${VAULT_TOKEN:-}
  if [[ -z $KV_TOKEN && -r $HOME/.vault-token ]]; then
    KV_TOKEN=$(tr -d '\r\n' <"$HOME/.vault-token")
  fi
  KV_META_NAME=""
}

# kv_bao ARGS...: run bao in a scrubbed environment. stdin passes through.
kv_bao() {
  (
    local v
    for v in $(compgen -e); do
      case $v in
        BAO_* | VAULT_* | HTTP_PROXY | http_proxy | HTTPS_PROXY | https_proxy | ALL_PROXY | all_proxy | NO_PROXY | no_proxy) unset "$v" ;;
      esac
    done
    export BAO_ADDR=$KV_ADDR BAO_TOKEN=$KV_TOKEN BAO_CLIENT_TIMEOUT=$KV_TIMEOUT
    exec bao "$@"
  )
}

# kv_have_token: on failure KV_CLASS=hard and nothing is sent.
kv_have_token() {
  if [[ -n $KV_TOKEN ]]; then
    return 0
  fi
  KV_CLASS=hard
  KV_ERR="no OpenBao token (VAULT_TOKEN unset, no ~/.vault-token): run just openbao-login"
  return 1
}

# kv_err_line ERRFILE: "Code 503: Vault is sealed", or the first line. Bash
# builtins only: the Home Manager activation PATH has no awk.
kv_err_line() {
  local line code="" star="" first="" out
  local code_re='Code: ([0-9]+)' star_re='^[[:space:]]*\*[[:space:]](.*)$'
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ -z $code && $line =~ $code_re ]]; then
      code=${BASH_REMATCH[1]}
    fi
    if [[ -z $star && $line =~ $star_re ]]; then
      star=${BASH_REMATCH[1]}
    fi
    if [[ -z $first && $line == *[![:space:]]* ]]; then
      first=$line
    fi
  done <"$1"
  if [[ -n $code ]]; then
    out="Code $code${star:+: $star}"
  else
    out=$first
  fi
  printf '%s\n' "${out:0:200}"
}

# kv_classify RC ERRFILE [404=missing]
#   hard: 401, 403, TLS/certificate errors. missing: path or version not found
#   ("No value found at secret/data/..." or ".../metadata/...": a real KV v2 mount
#   always names the mount; without it bao is reporting an empty-body 404 from a
#   gateway, or a v1 fallback, which is no answer). A bare "Code: 404." is missing only when the caller
#   passes 404=missing (the kv metadata patch of a missing path prints it);
#   anywhere else it can come from a gateway with no route, which is no answer.
#   cas: check-and-set refused. soft: everything else (5xx, 429, sealed,
#   refused, no such host, unreachable, timeouts, unexpected status).
kv_classify() {
  local rc=$1 err=$2 bare404=${3:-}
  KV_ERR=""
  if [[ $rc -eq 0 ]]; then
    KV_CLASS=ok
    return 0
  fi
  if grep -Eq "No value found at $KV_MOUNT/(data|metadata)/" "$err" || { [[ $bare404 == 404=missing ]] && grep -Eq 'Code: 404\.' "$err"; }; then
    KV_CLASS=missing
  elif grep -Eq 'Code: 40[13]\.' "$err"; then
    KV_CLASS=hard
  elif grep -Eq 'x509:|tls:' "$err"; then
    KV_CLASS=hard
  elif grep -Eq 'Code: 400\.' "$err" && grep -q 'check-and-set' "$err"; then
    KV_CLASS=cas
  else
    KV_CLASS=soft
  fi
  KV_ERR=$(kv_err_line "$err") || KV_ERR=""
  if [[ -z $KV_ERR ]]; then
    KV_ERR="bao exited with status $rc"
  fi
}

# kv_malformed: a number taken from a reply is not a plain positive integer of at
# most 9 digits (bash arithmetic wraps at 64 bits). Bash evaluates such strings
# as arithmetic wherever versions are compared, so nothing from a reply is used
# before this check. Sets the soft class.
kv_malformed() {
  KV_CLASS=soft
  KV_ERR="malformed response from OpenBao"
}

# kv_read NAME [VERSION]
kv_read() {
  local name=$1 ver=${2:-} out err rc=0 fields del destroyed dtype vtype
  local -a vflag=()
  KV_VALUE="" KV_SHA="" KV_VERSION=0 KV_CT="" KV_WRITER="" KV_MISSING="" KV_ERR=""
  kv_have_token || return 0
  if [[ -n $ver ]]; then
    vflag=("-version=$ver")
  fi
  out=$WORK/read.json
  err=$WORK/read.err
  kv_bao kv get -format=json "-mount=$KV_MOUNT" ${vflag[@]+"${vflag[@]}"} "$KV_PREFIX/$name" >"$out" 2>"$err" || rc=$?
  kv_classify "$rc" "$err"
  case $KV_CLASS in
    ok) ;;
    missing)
      KV_MISSING=absent
      return 0
      ;;
    *) return 0 ;;
  esac
  fields=$(jq -r '[
      (.data.metadata.version | tostring),
      .data.metadata.created_time,
      (.data.metadata.deletion_time // ""),
      (.data.metadata.destroyed | tostring),
      ((.data.data // null) | type),
      ((.data.data.value // null) | type),
      ((.data.data.writer // "") | tostring | gsub("[^A-Za-z0-9._-]"; "?"))
    ] | join("|")' "$out") || die "unreadable bao response for $name"
  IFS='|' read -r KV_VERSION KV_CT del destroyed dtype vtype KV_WRITER <<<"$fields"
  if [[ ! $KV_VERSION =~ ^[1-9][0-9]{0,8}$ ]]; then
    KV_VERSION=0 KV_CT="" KV_WRITER=""
    kv_malformed
    return 0
  fi
  if [[ $dtype == null ]]; then
    KV_CLASS=missing
    if [[ $destroyed == true ]]; then
      KV_MISSING=destroyed
    elif [[ -n $del ]]; then
      KV_MISSING=deleted
    else
      KV_MISSING=no-value
    fi
    return 0
  fi
  if [[ $vtype != string ]]; then
    KV_CLASS=missing
    KV_MISSING=no-value
    return 0
  fi
  KV_VALUE=$WORK/val.$name.$KV_VERSION
  jq -j '.data.data.value' "$out" >"$KV_VALUE" || die "cannot extract the value of $name"
  if [[ ! -s $KV_VALUE ]]; then
    KV_CLASS=missing
    KV_MISSING=empty
    KV_VALUE=""
    return 0
  fi
  KV_SHA=$(file_sha256 "$KV_VALUE") || die "cannot hash the value of $name"
}

# kv_meta NAME: KV_CUR = current_version. Cached per name until kv_meta_reset.
kv_meta() {
  local name=$1 rc=0
  if [[ $KV_META_NAME == "$name" ]]; then
    KV_CLASS=ok
    return 0
  fi
  KV_META_NAME=""
  KV_CUR=0
  kv_have_token || return 0
  KV_META_FILE=$WORK/meta.$name.json
  kv_bao kv metadata get -format=json "-mount=$KV_MOUNT" "$KV_PREFIX/$name" >"$KV_META_FILE" 2>"$WORK/meta.err" || rc=$?
  kv_classify "$rc" "$WORK/meta.err"
  if [[ $KV_CLASS != ok ]]; then
    return 0
  fi
  KV_CUR=$(jq -r '.data.current_version | tostring' "$KV_META_FILE") || die "unreadable metadata for $name"
  if [[ ! $KV_CUR =~ ^[1-9][0-9]{0,8}$ ]]; then
    KV_CUR=0
    kv_malformed
    return 0
  fi
  KV_META_NAME=$name
}
kv_meta_reset() { KV_META_NAME=""; }

# created_time of a retained version (empty when pruned or never existed).
kv_meta_ct() { jq -r --arg v "$1" '.data.versions[$v].created_time // empty' "$KV_META_FILE"; }

# Retained versions whose bytes still exist, newest first, one per line.
kv_meta_live_versions() {
  jq -r '.data.versions | to_entries
    | map(select(.value.deletion_time == "" and (.value.destroyed | not) and (.key | test("^[1-9][0-9]{0,8}$"))))
    | map(.key | tonumber) | sort | reverse | .[] | tostring' "$KV_META_FILE"
}

kv_writer() {
  local w
  w=$(/usr/sbin/scutil --get LocalHostName 2>/dev/null) || w=$(hostname -s 2>/dev/null) || w=unknown
  printf '%s' "$w" | tr -c 'A-Za-z0-9._-' '?'
}

# kv_pushable FILE: a value that survives the jq round trip and is not empty.
kv_pushable() {
  KV_REFUSE=""
  if [[ ! -s $1 ]]; then
    KV_REFUSE=empty
    return 1
  fi
  if ! jq -Rs . <"$1" | jq -j . | cmp -s - "$1"; then
    KV_REFUSE=not-utf8
    return 1
  fi
  return 0
}

# kv_write NAME CAS FILE: the request (value inside) goes to bao on stdin.
# Sets KV_NEWVERSION and KV_CT.
kv_write() {
  local name=$1 cas=$2 file=$3 writer rc=0 fields
  KV_NEWVERSION=0
  kv_have_token || return 0
  writer=$(kv_writer)
  jq -Rs --argjson cas "$cas" --arg writer "$writer" \
    '{options: {cas: $cas}, data: {value: ., writer: $writer}}' <"$file" >"$WORK/write.req" ||
    die "jq could not build the write request for $name"
  kv_bao write -format=json "$KV_MOUNT/data/$KV_PREFIX/$name" - <"$WORK/write.req" >"$WORK/write.json" 2>"$WORK/write.err" || rc=$?
  rm -f "$WORK/write.req"
  kv_classify "$rc" "$WORK/write.err"
  if [[ $KV_CLASS != ok ]]; then
    return 0
  fi
  fields=$(jq -r '[(.data.version | tostring), .data.created_time] | join("|")' "$WORK/write.json") || die "unreadable write response for $name"
  IFS='|' read -r KV_NEWVERSION KV_CT <<<"$fields"
  KV_META_NAME=""
  if [[ ! $KV_NEWVERSION =~ ^[1-9][0-9]{0,8}$ ]]; then
    KV_NEWVERSION=0 KV_CT=""
    kv_malformed
  fi
}

# kv_enforce_cas NAME: cas_required=true on the path, its other settings kept.
# Needs the patch capability on secret/metadata/... (update alone gets a 403).
kv_enforce_cas() {
  local name=$1 rc=0
  kv_have_token || return 0
  kv_bao kv metadata patch -cas-required=true "-mount=$KV_MOUNT" "$KV_PREFIX/$name" >"$WORK/patch.out" 2>"$WORK/patch.err" || rc=$?
  kv_classify "$rc" "$WORK/patch.err" 404=missing
}
