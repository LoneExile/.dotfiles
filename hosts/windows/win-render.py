#!/usr/bin/env python3
"""Render the bundle that win-sync (hosts/windows/win-sync.sh) sends to a Windows host.

    win-render.py REPO NAME STAGE SSH_SETTINGS TERN_DIR TARGET_ADDRESS MAC_LINE

REPO is the dotfiles checkout, NAME the host (hosts/windows/NAME/), STAGE the bundle directory,
SSH_SETTINGS the Mac's programs.ssh.settings as JSON (nix eval --json), TERN_DIR the Mac's Tern directory
(its host list `hosts` and its pins `known_hosts`), TARGET_ADDRESS the Windows host's address and MAC_LINE
the Mac's own Tern line, <user>@<endpoint id><tab><name>. win-sync writes the secret files first
(omp/env, ssh/id_ed25519 and its .pub); this script writes everything else, and files.tsv, the table
apply.ps1 installs from:

    omp/config.yml, omp/models.yml   the repo copies (home/omp/)
    omp/mcp.json                     home/omp/mcp.json with hosts/windows/NAME/mcp-overrides.json applied
                                     ("drop": names, "replace": name -> server) and ${HOME} turned into
                                     ${USERPROFILE} in every string (Windows sets USERPROFILE, not HOME)
    plugins/*, plugins.sha256        the captured plugin manifests (home/omp/plugins/) and their hash
    tern/settings.json               home/tern/settings.json
    tern-hosts.txt, tern-pins.txt    the Mac's Tern host list (the hosts its Tern window lists), without the
                                     lines that name TARGET_ADDRESS, then MAC_LINE; and the host key the Mac
                                     has pinned for each [user@]host[:port] line (the port is 8376 when none
                                     is given), plus each endpoint id the Mac pinned with that same key (so
                                     Tern falls back to the relay when the address does not answer); a host
                                     the Mac has not pinned is an error. An endpoint id line needs no pin:
                                     the id is the key.
    ssh/config                       the Host blocks of ssh-hosts.txt and `Host *`, from the Mac's
                                     settings, with IdentityFile set to the host's own key and the
                                     macOS-only options left out
    winget.txt                       the package ids of hosts/windows/NAME/winget.txt

Exit 0, or 1 with one line on stderr.
"""

import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

# Options that only Apple's ssh knows: Windows' OpenSSH refuses a config that holds one.
MAC_ONLY_OPTIONS = {"UseKeychain"}
HOST_KEY = "~/.ssh/id_ed25519"
TERN_DEFAULT_PORT = 8376
PLUGIN_FILES = ("package.json", "bun.lock", "omp-plugins.lock.json")


class RenderError(Exception):
    pass


def read_list(path):
    """The non-empty lines of a list file, without `#` comments and surrounding spaces."""
    if not path.is_file():
        raise RenderError(f"missing {path}")
    out = []
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].rstrip()
        if line.strip():
            out.append(line.strip(" "))
    if not out:
        raise RenderError(f"{path} lists nothing")
    return out


def replace_home(value):
    if isinstance(value, str):
        return value.replace("${HOME}", "${USERPROFILE}")
    if isinstance(value, list):
        return [replace_home(v) for v in value]
    if isinstance(value, dict):
        return {k: replace_home(v) for k, v in value.items()}
    return value


def render_mcp(mac, overrides):
    servers = mac.get("mcpServers")
    if not isinstance(servers, dict):
        raise RenderError("home/omp/mcp.json has no mcpServers object")
    drop = overrides.get("drop", [])
    replace = overrides.get("replace", {})
    if not isinstance(drop, list) or not isinstance(replace, dict):
        raise RenderError('mcp-overrides.json must hold "drop" (a list) and "replace" (an object)')
    unknown = sorted((set(drop) | set(replace)) - set(servers))
    if unknown:
        raise RenderError(f"mcp-overrides.json names servers home/omp/mcp.json does not have: {', '.join(unknown)}")
    both = sorted(set(drop) & set(replace))
    if both:
        raise RenderError(f"mcp-overrides.json both drops and replaces: {', '.join(both)}")
    out = {}
    for key, value in mac.items():
        if key == "mcpServers":
            value = {n: replace.get(n, s) for n, s in servers.items() if n not in drop}
        elif key == "disabledServers" and isinstance(value, list):
            value = [n for n in value if n not in drop]
        out[key] = value
    return replace_home(out)


def ssh_value_lines(key, value):
    if isinstance(value, bool):
        return [f"  {key} {'yes' if value else 'no'}"]
    if isinstance(value, list):
        return [line for v in value for line in ssh_value_lines(key, v)]
    if value is None:
        return []
    return [f"  {key} {value}"]


def ssh_block(entry):
    data = entry.get("data") if isinstance(entry, dict) else None
    if not isinstance(data, dict) or not isinstance(data.get("header"), str):
        raise RenderError("an entry of programs.ssh.settings has no data.header")
    lines = [data["header"]]
    for key, value in data.items():
        if key == "header" or key in MAC_ONLY_OPTIONS:
            continue
        if key == "IdentityFile":
            value = HOST_KEY
        lines.extend(ssh_value_lines(key, value))
    return "\n".join(lines) + "\n"


def ssh_entry(settings, alias, where):
    """The one Host block of programs.ssh that names ALIAS; WHERE names the list file for the error."""
    if not isinstance(settings, dict):
        raise RenderError("the SSH settings are not a JSON object")
    found = [e for name, e in settings.items() if name != "*" and alias in name.split()]
    if len(found) != 1:
        raise RenderError(f"{where}: {alias} matches {len(found)} Host blocks of programs.ssh (want 1)")
    return found[0]


def render_ssh(settings, aliases):
    blocks = [ssh_block(ssh_entry(settings, alias, "ssh-hosts.txt")) for alias in aliases]
    if "*" in settings:
        blocks.append(ssh_block(settings["*"]))
    head = "# Written by win-sync (hosts/windows/win-sync.sh) from programs.ssh of the dotfiles; an edit here\n" \
           "# stays until that changes (the old file is then kept as config.dotfiles-backup).\n"
    return head + "\n".join(blocks)


ENDPOINT_ID = re.compile(r"[0-9a-f]{64}")


def parse_tern_line(line):
    """(user, host, port) of a line of Tern's host list: [user@]host[:port] or [user@]<endpoint id>, then
    optionally a tab and the name Tern shows."""
    target = line.split("\t", 1)[0].strip()
    m = re.fullmatch(r"(?:([A-Za-z0-9._-]+)@)?([A-Za-z0-9.-]+)(?::([0-9]{1,5}))?", target)
    if not m:
        raise RenderError(f"the Tern host list has a line that is not [user@]host[:port]: {line!r}")
    return m.groups()


def mac_tern_hosts(tern_dir, target_address, mac_line):
    """The Mac's Tern host list without the Windows host itself, then the Mac's own line."""
    hosts = tern_dir / "hosts"
    if not hosts.is_file():
        raise RenderError(f"no Tern host list on this Mac at {hosts}")
    out = []
    for line in hosts.read_text().splitlines():
        line = line.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if parse_tern_line(line)[1] != target_address:
            out.append(line)
    _, host, port = parse_tern_line(mac_line)
    if not ENDPOINT_ID.fullmatch(host) or port:
        raise RenderError(f"the Mac's own Tern line is not <user>@<endpoint id>: {mac_line!r}")
    if mac_line not in out:
        out.append(mac_line)
    return out


def tern_pin_key(line):
    """The known_hosts key of a Tern host line, or None for an endpoint id (the id is the key)."""
    _, host, port = parse_tern_line(line)
    if ENDPOINT_ID.fullmatch(host):
        return None
    return f"{host}:{port or TERN_DEFAULT_PORT}"


def render_tern_pins(hosts, known_hosts):
    keys = [k for k in (tern_pin_key(spec) for spec in hosts) if k]
    if keys and not known_hosts.is_file():
        raise RenderError(f"no Tern known_hosts on this Mac at {known_hosts}")
    pins = {}
    linked = {}
    if keys:
        for line in known_hosts.read_text().splitlines():
            fields = line.split()
            if len(fields) == 2:
                pins.setdefault(fields[0], fields[1])
                if ENDPOINT_ID.fullmatch(fields[0]):
                    linked.setdefault(fields[1], []).append(fields[0])
    out = []
    for key in keys:
        if key not in pins:
            raise RenderError(f"this Mac has no pinned Tern host key for {key}: connect to it once from the Mac (tern remote doctor) first")
        for pinned in [key, *linked.get(pins[key], [])]:
            line = f"{pinned} {pins[key]}"
            if line not in out:
                out.append(line)
    return "\n".join(out) + "\n"


def copy(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)


def render(repo, name, stage, ssh_settings, tern_dir, target_address, mac_line):
    host = repo / "hosts" / "windows" / name
    if not host.is_dir():
        raise RenderError(f"no host directory {host}")
    for secret in ("omp/env", "ssh/id_ed25519", "ssh/id_ed25519.pub"):
        if not (stage / secret).is_file():
            raise RenderError(f"the bundle has no {secret} (win-sync writes it first)")

    omp = repo / "home" / "omp"
    copy(omp / "config.yml", stage / "omp" / "config.yml")
    copy(omp / "models.yml", stage / "omp" / "models.yml")
    overrides = json.loads((host / "mcp-overrides.json").read_text())
    mcp = render_mcp(json.loads((omp / "mcp.json").read_text()), overrides)
    (stage / "omp" / "mcp.json").write_text(json.dumps(mcp, indent=2, ensure_ascii=False) + "\n")

    digest = hashlib.sha256()
    for f in PLUGIN_FILES:
        data = (omp / "plugins" / f).read_bytes()
        digest.update(f.encode() + b"\0" + data + b"\0")
        copy(omp / "plugins" / f, stage / "plugins" / f)
    (stage / "plugins.sha256").write_text(digest.hexdigest() + "\n")

    settings = json.loads(ssh_settings.read_text())
    (stage / "ssh" / "config").write_text(render_ssh(settings, read_list(host / "ssh-hosts.txt")))

    copy(repo / "home" / "tern" / "settings.json", stage / "tern" / "settings.json")
    hosts = mac_tern_hosts(tern_dir, target_address, mac_line)
    (stage / "tern-hosts.txt").write_text("\n".join(hosts) + "\n")
    (stage / "tern-pins.txt").write_text(render_tern_pins(hosts, tern_dir / "known_hosts"))
    (stage / "winget.txt").write_text("\n".join(read_list(host / "winget.txt")) + "\n")

    rows = [
        ("file", "omp/config.yml", "~/.omp/agent/config.yml"),
        ("file", "omp/models.yml", "~/.omp/agent/models.yml"),
        ("file", "omp/mcp.json", "~/.omp/agent/mcp.json"),
        ("secret", "omp/env", "~/.omp/.env"),
    ]
    rows += [("file", f"plugins/{f}", f"~/.omp/plugins/{f}") for f in PLUGIN_FILES]
    rows += [
        ("file", "tern/settings.json", "%APPDATA%/Tern/settings.json"),
        ("file", "ssh/config", "~/.ssh/config"),
        ("secret", "ssh/id_ed25519", "~/.ssh/id_ed25519"),
        ("file", "ssh/id_ed25519.pub", "~/.ssh/id_ed25519.pub"),
    ]
    (stage / "files.tsv").write_text("".join("\t".join(r) + "\n" for r in rows))


def main(argv):
    if len(argv) != 8:
        print("usage: win-render.py REPO NAME STAGE SSH_SETTINGS TERN_DIR TARGET_ADDRESS MAC_LINE", file=sys.stderr)
        return 2
    repo, name, stage, ssh_settings, tern_dir = (Path(a) for a in argv[1:6])
    try:
        render(repo, str(name), stage, ssh_settings, tern_dir, argv[6], argv[7])
    except (RenderError, OSError, ValueError) as e:
        print(f"win-sync: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
