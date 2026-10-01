# dotfiles-secrets: the secret-sync engine with its tools pinned by nix. The
# runtime inputs are put in front of PATH inside this wrapper only, so the
# user's own bao and jq stay what they are.
{
  lib,
  bash,
  coreutils,
  jq,
  openbao,
  writeShellApplication,
}: let
  # The engine's scripts only: no tests, no atuin-login.sh, no contract-check.sh.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./materialize.sh
      ./common.sh
      ./kv.sh
      ./decide.sh
      ./state.sh
      ./inspect.sh
      ./pull.sh
      ./summary.sh
      ./push.sh
      ./status.sh
      ./apply.sh
      ./sync.sh
      ./enforce.sh
    ];
  };
in
  writeShellApplication {
    name = "dotfiles-secrets";
    runtimeInputs = [openbao jq coreutils];
    text = ''
      exec ${bash}/bin/bash ${src}/materialize.sh "$@"
    '';
  }
