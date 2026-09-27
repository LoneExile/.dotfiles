# Host Template

Optional per-host settings for a Mac in this flake.

## Add a host

```nix
# flake.nix, `hosts` table: this alone is a complete host
<hostname> = {username = "<id -un on that Mac>";};
```

`lib.mkDarwin` derives `networking.hostName`, `users.users.<username>.home`
(`/Users/<username>`, or `homeDirectory` if set in the entry),
`system.primaryUser`, the Home Manager user, the Homebrew owner and nix
`trusted-users` from that entry; `hosts/common` adds `computerName` and the
owner's full name. No `/Users/<name>` path is written anywhere else.

Only when a machine needs its own settings (display mode, extra packages,
macOS defaults):

```bash
cp -r hosts/_template hosts/<hostname>
$EDITOR hosts/<hostname>/default.nix
```

Then `just build <hostname>` / `just switch <hostname>`.

## What you get

- `hosts/common/default.nix` is imported automatically (shared base settings,
  Nix gc/optimisation, allowUnfree).
- The `home/default.nix` Home Manager config is wired in by `lib.mkDarwin` for
  the user you specify in `username`. No per-user file is needed.
- Profiles (`development`, `personal`, ...) load the corresponding
  `profiles/<name>.nix`; set `profiles` in the `hosts` entry to change them.

See `hosts/le/default.nix` for an example (display resolution).
