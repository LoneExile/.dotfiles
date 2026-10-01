# kv.sh: OpenBao KV v2 transport for the secret-sync scripts. Sourced, not run.
# Needs common.sh (file_sha256, WORK) plus the bao and jq binaries.
#
# Every vault call goes through kv_bao, which clears each BAO_* / VAULT_*
# variable of the caller and then sets only the address, token and timeout
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
    for v in $(compgen -e | grep -E '^(BAO|VAULT)_[A-Za-z0-9_]*$' || true); do
      unset "$v"
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

# kv_err_line ERRFILE: "Code 503: Vault is sealed", or the first line.
kv_err_line() {
  awk '
    /Code: [0-9]+/ && code == "" { code = $0; sub(/.*Code: /, "", code); sub(/\..*/, "", code) }
    /^[ \t]*\* / && star == "" { star = $0; sub(/^[ \t]*\* /, "", star) }
    NF && first == "" { first = $0 }
    END {
      if (code != "") { print "Code " code (star != "" ? ": " star : "") }
      else { print first }
    }' "$1" | cut -c1-200
}

# kv_classify RC ERRFILE
#   hard: 401, 403, TLS/certificate errors. missing: path or version not found.
#   cas: check-and-set refused. soft: everything else (5xx, 429, sealed,
#   refused, no such host, unreachable, timeouts, unexpected status).
kv_classify() {
  local rc=$1 err=$2
  KV_ERR=""
  if [[ $rc -eq 0 ]]; then
    KV_CLASS=ok
    return 0
  fi
  if grep -q 'No value found at' "$err" || grep -Eq 'Code: 404\.' "$err"; then
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
  KV_ERR=$(kv_err_line "$err")
  if [[ -z $KV_ERR ]]; then
    KV_ERR="bao exited with status $rc"
  fi
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
  KV_CUR=$(jq -r '.data.current_version' "$KV_META_FILE") || die "unreadable metadata for $name"
  KV_META_NAME=$name
}
kv_meta_reset() { KV_META_NAME=""; }

# created_time of a retained version (empty when pruned or never existed).
kv_meta_ct() { jq -r --arg v "$1" '.data.versions[$v].created_time // empty' "$KV_META_FILE"; }

# Retained versions whose bytes still exist, newest first, one per line.
kv_meta_live_versions() {
  jq -r '.data.versions | to_entries
    | map(select(.value.deletion_time == "" and (.value.destroyed | not)))
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
}
