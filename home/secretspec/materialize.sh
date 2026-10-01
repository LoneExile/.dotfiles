#!/usr/bin/env bash
# Keeps the secret files on this Mac in sync with OpenBao (KV v2, through bao
# and jq). Run it as `dotfiles-secrets`, the nix wrapper that pins both.
#
#   apply            Home Manager activation: pulls what is safe, never writes
#                    the vault, never prompts
#   status           read-only overview of every secret
#   sync             interactive review, push and pull (needs a terminal)
#   sync --push NAME push the local file of one secret, no prompts
#   list             the table below
#
# Design: docs/superpowers/specs/2026-10-01-secretspec-smart-sync-design.md
# (local, untracked).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for lib in common kv decide state inspect pull summary push status apply sync; do
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/$lib.sh"
done

# NAME|path-from-HOME|mode. The only table. Every file is byte-exact.
SECRETS=(
  "SSH_ID_ED25519|.ssh/id_ed25519|600"
  "SSH_ID_ED25519_PUB|.ssh/id_ed25519.pub|644"
  "SSH_ID_ED25519_OC|.ssh/id_ed25519.oc|600"
  "SSH_ID_ED25519_OC_PUB|.ssh/id_ed25519.oc.pub|644"
  "SSH_ID_ED25519_UNIT_PX|.ssh/id_ed25519_unit_px|600"
  "SSH_ID_CRYPT|.ssh/id_crypt|600"
  "SSH_ID_CRYPT_PUB|.ssh/id_crypt.pub|644"
  "SSH_LINE_PAYMENT_GATEWAY|.ssh/line-payment-gateway|600"
  "SSH_LINE_PAYMENT_GATEWAY_PUB|.ssh/line-payment-gateway.pub|644"
  "ATUIN_KEY|.local/share/atuin/key|600"
  "NPMRC|.npmrc|600"
  "ATUIN_AI_TOKEN|.config/atuin/ai-token|600"
  "OMP_ENV|.omp/.env|600"
  "TOFU_BACKBONE_CLUSTER_PASS|.config/tofu/backbone-cluster.pass|600"
)

# lookup_secret NAME: sets S_REL and S_MODE, or dies.
lookup_secret() {
  local spec n
  for spec in "${SECRETS[@]}"; do
    IFS='|' read -r n S_REL S_MODE <<<"$spec"
    if [[ $n == "$1" ]]; then
      return 0
    fi
  done
  die "unknown secret '$1' (dotfiles-secrets list shows them)"
}

# list: NAME PATH-FROM-HOME MODE per secret.
cmd_list() {
  local spec name rel mode
  for spec in "${SECRETS[@]}"; do
    IFS='|' read -r name rel mode <<<"$spec"
    printf '%s %s %s\n' "$name" "$rel" "$mode"
  done
}

main() {
  case ${1:-} in
    apply) cmd_apply ;;
    status) cmd_status ;;
    sync)
      shift
      cmd_sync "$@"
      ;;
    list) cmd_list ;;
    *) die "usage: materialize.sh apply|status|sync [--push NAME]|list" ;;
  esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
