# Host Template

Starter template for adding a new MacBook to this flake.

## Add a host in 4 steps

```bash
# 1. Copy this directory
cp -r hosts/_template hosts/$(hostname)

# 2. Replace HOSTNAME / USERNAME / "Full Name" in default.nix
$EDITOR hosts/$(hostname)/default.nix

# 3. Register the host in flake.nix under darwinConfigurations
#    e.g.
#      "<hostname>" = lib.mkDarwin {
#        hostname = "<hostname>";
#        username = "<username>";
#        system   = "aarch64-darwin";
#        profiles = { development = true; personal = true; };
#      };

# 4. Build & switch
just build $(hostname)
just switch $(hostname)
```

## What you get

- `hosts/common/default.nix` is imported automatically (shared base settings,
  Nix gc/optimisation, allowUnfree).
- The `home/default.nix` Home Manager config is wired in by `lib.mkDarwin` for
  the user you specify in `username`. No per-user file is needed.
- Profiles passed to `lib.mkDarwin` (`development`, `personal`, ...) load the
  corresponding `profiles/<name>.nix`.

## Customising the template

Heavy host-specific bits — Homebrew brews/casks, fonts, macOS dock prefs,
displayplacer activation — live in the host file itself, not in a profile.
See `hosts/le/default.nix` for a fully customised example.
