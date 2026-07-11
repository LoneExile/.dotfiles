# Lint Exemptions

This file documents pre-existing lint warnings that are intentionally left in place. The 2026-04-30 modular-multihost-cleanup refactor surfaced these but did not introduce them; fixing them is out of scope for that change.

## deadnix

- **`home/default.nix:2`** — unused lambda pattern `config`. Pre-existing in the user-authored Home Manager config; the module header keeps `config` for symmetry with the standard `{ config, pkgs, lib, ... }` signature. The nixCats callback patterns (`settings`, `categories`, `name`) previously exempted here were removed with nixCats.
- **`lib/builders.nix:3,4,28,88,174,176,208,214`** — unused `outputs` / `stateVersion` / `final` / `pkgs` / `config` lambda patterns. These are pass-through args in the public `mkDarwin` / `mkProfile` / `mkModule` API; removing them would be a breaking signature change.
- **`lib/utils.nix:3`** — unused `outputs` lambda pattern. Same pass-through reasoning as `builders.nix`.
- **`scripts/validate-modules.nix:51,53`** — unused lambda args `desc` / `cond` in helper definitions kept as documentation of the intended signature.

## statix

- **`home/default.nix:8,11,44,76,78,84`** — `W20` repeated keys (`home.*` and `programs.*`). Pre-existing user-organization choice in the Home Manager file; the writer prefers grouping by feature (e.g. `programs.gpg.enable` near `programs.gpg.settings`) over flattening into a single `programs = { ... }` attrset.
- **`templates/default/flake.nix:30`**, **`templates/development/flake.nix:29`** — `W04` `lib = nix-config.lib;` could be `inherit (nix-config) lib;`. Pre-existing template style; templates are independent flake bootstraps not consumed by this repo's build.

## Policy

New code must not add new entries here. If a new warning appears in CI:
1. Prefer fixing it in the change that introduced it.
2. If unavoidable, add a `# deadnix-skip: <reason>` or `# statix-skip: <reason>` comment at the call site AND a one-line entry in this file with date and reason.
