#!/usr/bin/env bash
# Materialize secretspec secrets with 3-way last-sync.
# apply: activation. Never pushes. Pull vault-newer, leave local-newer, fail on conflict.
# sync: interactive TTY. nvim -d (or diff -u) then y/N.
set -euo pipefail

SECRETSPEC_BIN="${SECRETSPEC_BIN:-$HOME/.cargo/bin/secretspec}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECRETSPEC_FILE="${SECRETSPEC_FILE:-$REPO_ROOT/secretspec.toml}"
SECRETSPEC_REASON="${SECRETSPEC_REASON:-secretspec materialize}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/secretspec"
PROVIDER="openbao"

# name|relpath-from-HOME|mode|keep|strip
SECRETS=(
  "SSH_ID_ED25519|.ssh/id_ed25519|600|keep"
  "SSH_ID_ED25519_PUB|.ssh/id_ed25519.pub|644|keep"
  "SSH_ID_ED25519_OC|.ssh/id_ed25519.oc|600|keep"
  "SSH_ID_ED25519_OC_PUB|.ssh/id_ed25519.oc.pub|644|keep"
  "SSH_ID_ED25519_UNIT_PX|.ssh/id_ed25519_unit_px|600|keep"
  "SSH_ID_CRYPT|.ssh/id_crypt|600|keep"
  "SSH_ID_CRYPT_PUB|.ssh/id_crypt.pub|644|keep"
  "SSH_LINE_PAYMENT_GATEWAY|.ssh/line-payment-gateway|600|keep"
  "SSH_LINE_PAYMENT_GATEWAY_PUB|.ssh/line-payment-gateway.pub|644|keep"
  "ATUIN_KEY|.local/share/atuin/key|600|strip"
  "NPMRC|.npmrc|600|keep"
  "ATUIN_CONFIG|.config/atuin/config.toml|600|keep"
  "OMP_ENV|.omp/.env|600|keep"
)

die() {
  echo "error: $*" >&2
  exit 1
}

require_bin() {
  if [[ ! -x $SECRETSPEC_BIN ]]; then
    echo "error: secretspec not found at $SECRETSPEC_BIN; SSH keys not materialized" >&2
    echo "install it with: curl -sSL https://install.secretspec.dev | sh" >&2
    exit 1
  fi
}

file_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

ss_get() {
  if ! "$SECRETSPEC_BIN" -f "$SECRETSPEC_FILE" --reason "$SECRETSPEC_REASON" get -p "$PROVIDER" "$1"; then
    echo "error: could not resolve secret '$1' from OpenBao" >&2
    echo "run 'just openbao-login', then 'just switch' to retry" >&2
    exit 1
  fi
}

ss_set_file() {
  local name=$1 file=$2
  local value
  value=$(cat "$file"; printf x)
  value=${value%x}
  if ! "$SECRETSPEC_BIN" -f "$SECRETSPEC_FILE" --reason "$SECRETSPEC_REASON" set -p "$PROVIDER" "$name" -- "$value"; then
    die "could not set secret '$name' in OpenBao"
  fi
}

write_canonical() {
  local name=$1 dest=$2 nl=$3
  if [[ $nl == strip ]]; then
    local raw
    raw=$(ss_get "$name")
    printf '%s' "$raw" >"$dest"
  else
    ss_get "$name" >"$dest"
  fi
}

record_hash() {
  local name=$1 hash=$2
  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR"
  local tmp
  tmp=$(mktemp "$STATE_DIR/.${name}.XXXXXX")
  printf '%s\n' "$hash" >"$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$STATE_DIR/${name}.sha256"
}

read_hash() {
  local f="$STATE_DIR/${1}.sha256"
  if [[ ! -f $f ]]; then
    echo ""
    return 0
  fi
  tr -d ' \n' <"$f"
}

# dest_exists: 1/0
classify() {
  local dest_exists=$1 local_hash=$2 vault_hash=$3 last_hash=$4
  if [[ $dest_exists == 0 ]]; then
    echo pull
    return
  fi
  if [[ $local_hash == "$vault_hash" ]]; then
    echo equal
    return
  fi
  if [[ -z $last_hash ]]; then
    echo push
    return
  fi
  if [[ $local_hash == "$last_hash" && $vault_hash != "$last_hash" ]]; then
    echo pull
    return
  fi
  if [[ $vault_hash == "$last_hash" && $local_hash != "$last_hash" ]]; then
    echo push
    return
  fi
  echo conflict
}

ensure_layout() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  mkdir -p "$HOME/.local/share/atuin"
  chmod 700 "$HOME/.local/share/atuin"
  mkdir -p "$HOME/.config/atuin"
  mkdir -p "$HOME/.omp"
}

install_dest() {
  local src=$1 dest=$2 mode=$3
  local parent tmp
  parent=$(dirname "$dest")
  mkdir -p "$parent"
  tmp=$(mktemp "$parent/.$(basename "$dest").XXXXXX")
  cat "$src" >"$tmp"
  chmod "$mode" "$tmp"
  mv "$tmp" "$dest"
}

is_text_secret() {
  case $1 in
    OMP_ENV | ATUIN_CONFIG | NPMRC) return 0 ;;
    *) return 1 ;;
  esac
}

byte_count() {
  wc -c <"$1" | tr -d ' '
}

show_diff() {
  local name=$1 dest=$2 canonical=$3
  if [[ ! -f $dest ]]; then
    echo "local file missing: $dest"
    return 0
  fi
  if command -v nvim >/dev/null 2>&1; then
    nvim -d -R -n -i NONE --cmd 'set noswapfile noundofile nobackup nowritebackup shadafile=NONE' -- "$dest" "$canonical"
    return 0
  fi
  if is_text_secret "$name"; then
    diff -u --label "openbao/$name" --label "$dest" "$canonical" "$dest" || true
  else
    echo "bytes differ ($(byte_count "$dest") vs $(byte_count "$canonical"))"
  fi
}

confirm_yn() {
  local msg=$1 ans
  printf '%s' "$msg"
  read -r ans || true
  [[ $ans == [yY] ]]
}

do_pull() {
  local name=$1 dest=$2 mode=$3 canonical=$4
  install_dest "$canonical" "$dest" "$mode"
  record_hash "$name" "$(file_sha256 "$dest")"
  echo "pull $name"
}

do_push() {
  local name=$1 dest=$2
  ss_set_file "$name" "$dest"
  record_hash "$name" "$(file_sha256 "$dest")"
  echo "push $name"
}

# classify_dest name dest canonical
classify_dest() {
  local name=$1 dest=$2 canonical=$3
  local dest_exists=0 local_hash="" vault_hash last_hash
  vault_hash=$(file_sha256 "$canonical")
  last_hash=$(read_hash "$name")
  if [[ -f $dest ]]; then
    dest_exists=1
    local_hash=$(file_sha256 "$dest")
  fi
  classify "$dest_exists" "$local_hash" "$vault_hash" "$last_hash"
}

cmd_apply() {
  require_bin
  ensure_layout
  MATERIALIZE_WORKDIR=$(mktemp -d)
  trap 'rm -rf "$MATERIALIZE_WORKDIR"' EXIT


  local conflicts=()
  local spec name rel mode nl dest canonical action
  for spec in "${SECRETS[@]}"; do
    IFS='|' read -r name rel mode nl <<<"$spec"
    dest="$HOME/$rel"
    canonical="$MATERIALIZE_WORKDIR/${name}.openbao"

    write_canonical "$name" "$canonical" "$nl"
    chmod 600 "$canonical"
    action=$(classify_dest "$name" "$dest" "$canonical")

    case $action in
      equal)
        chmod "$mode" "$dest"
        record_hash "$name" "$(file_sha256 "$dest")"
        ;;
      pull)
        do_pull "$name" "$dest" "$mode" "$canonical"
        ;;
      push)
        echo "local drifted $name — run: just secretspec-sync"
        ;;
      conflict)
        echo "conflict $name"
        conflicts+=("$name")
        ;;
    esac
  done

  if ((${#conflicts[@]} > 0)); then
    echo "error: secret conflict (local and OpenBao both changed): ${conflicts[*]}" >&2
    echo "run 'just secretspec-sync' to resolve" >&2
    exit 1
  fi
}

cmd_sync() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    die "just secretspec-sync requires a TTY"
  fi
  require_bin
  ensure_layout
  MATERIALIZE_WORKDIR=$(mktemp -d)
  trap 'rm -rf "$MATERIALIZE_WORKDIR"' EXIT


  local spec name rel mode nl dest canonical action ans
  for spec in "${SECRETS[@]}"; do
    IFS='|' read -r name rel mode nl <<<"$spec"
    dest="$HOME/$rel"
    canonical="$MATERIALIZE_WORKDIR/${name}.openbao"

    write_canonical "$name" "$canonical" "$nl"
    chmod 600 "$canonical"
    action=$(classify_dest "$name" "$dest" "$canonical")
    case $action in
      equal)
        if [[ -f $dest ]]; then
          chmod "$mode" "$dest"
        fi
        record_hash "$name" "$(file_sha256 "$dest")"
        ;;
      pull)
        show_diff "$name" "$dest" "$canonical"
        if confirm_yn "pull $name from OpenBao? [y/N] "; then
          do_pull "$name" "$dest" "$mode" "$canonical"
        else
          echo "skip $name"
        fi
        ;;
      push)
        show_diff "$name" "$dest" "$canonical"
        if confirm_yn "push $name to OpenBao? [y/N] "; then
          do_push "$name" "$dest"
        else
          echo "skip $name"
        fi
        ;;
      conflict)
        echo "conflict $name (local and OpenBao both changed)"
        show_diff "$name" "$dest" "$canonical"
        printf 'conflict %s: [p]ush local / pul[l] vault / [s]kip? ' "$name"
        read -r ans || true
        case $ans in
          p | P) do_push "$name" "$dest" ;;
          l | L) do_pull "$name" "$dest" "$mode" "$canonical" ;;
          *) echo "skip $name" ;;
        esac
        ;;
    esac
  done
}

main() {
  case ${1:-} in
    apply) cmd_apply ;;
    sync) cmd_sync ;;
    *) die "usage: materialize.sh apply|sync" ;;
  esac
}

main "$@"
