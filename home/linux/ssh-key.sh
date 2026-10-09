# shellcheck shell=bash
# ensure_ssh_key SSH-KEYGEN KEY PURPOSE: make the ed25519 key KEY (and KEY.pub) of the user, once.
# Sourced by the Home Manager activation of home/linux/agent.nix, which supplies `run` (it prints instead of acting on a dry run).
# The key is made ON this machine, for this user only: its private half never leaves it, is never printed, and is in no vault.
#   - KEY missing: made without a passphrase (it is used by ssh in the background), mode 600, with the comment
#     user@host PURPOSE built here at run time (no machine name is in the repo); the fingerprint is said, nothing else.
#   - KEY there (any type, a link too): never replaced, never changed. If only its public half is missing, that is
#     derived from it.
#   - only KEY.pub there, no KEY: left alone, nothing is made (a new private key beside an old public half would not pair).
#   - ~/.ssh missing: made with mode 700; an existing one keeps its mode.
#   - ssh-keygen fails: said on stderr, nothing is left behind, and the activation goes on.
# The key is made under a temporary name and moved with `mv -n`, which never overwrites: a key that appears meanwhile wins. The private key goes first: a stop between the two
# moves leaves a private key without its public half, which the next run derives (see above).
ensure_ssh_key() {
  local keygen=$1 key=$2 purpose=$3 dir tmp comment fp
  dir=$(dirname "$key")
  if [ -e "$key" ] || [ -L "$key" ]; then
    if [ ! -L "$key" ] && [ ! -e "$key.pub" ] && [ ! -L "$key.pub" ]; then
      (umask 022 && "$keygen" -y -f "$key" >"$key.pub") 2>/dev/null || {
        rm -f "$key.pub"
        printf 'ensure-ssh-key: could not derive the public half of %s\n' "$key" >&2
      }
    fi
    printf 'ensure-ssh-key: kept the existing key %s\n' "$key"
    return 0
  fi
  if [ -e "$key.pub" ] || [ -L "$key.pub" ]; then
    printf 'ensure-ssh-key: %s.pub is there without its private key: left alone, no key was made\n' "$key" >&2
    return 0
  fi
  [ -d "$dir" ] || run install -d -m 700 "$dir" || return 0
  comment="$(id -un)@$(uname -n) $purpose"
  tmp=$dir/.$(basename "$key").new.$$
  rm -f "$tmp" "$tmp.pub"
  if (umask 077 && run "$keygen" -q -t ed25519 -N '' -C "$comment" -f "$tmp") >/dev/null 2>&1 && [ -s "$tmp" ] && [ -s "$tmp.pub" ]; then
    mv -n "$tmp" "$key" && mv -n "$tmp.pub" "$key.pub"
    rm -f "$tmp" "$tmp.pub"
    fp=$("$keygen" -l -f "$key" 2>/dev/null | cut -d' ' -f2) || fp=
    printf 'ensure-ssh-key: created %s (%s)\n' "$key" "$fp"
  else
    rm -f "$tmp" "$tmp.pub"
    printf 'ensure-ssh-key: could not create %s (ssh-keygen failed); nothing was left behind\n' "$key" >&2
  fi
  return 0
}
