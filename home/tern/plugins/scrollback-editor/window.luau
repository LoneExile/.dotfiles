--!strict
-- Open scrollback in editor (`open_scrollback`, ⌃A e in home/tern/settings.json) in nvim, or vim when the host has no
-- nvim. Tern's own command writes the scrollback to a file and hands it to the Mac's default text app (TextEdit;
-- measured on Tern 0.7.3), whatever EDITOR says. This override runs first and skips it for terminal and agent panes:
-- a new tab, in the pane's session and so on the pane's host, captures the whole scrollback with `tern capture`
-- into a temporary file, opens it at its last line, and removes the file when the editor quits (the tab closes then).
-- Other pane kinds keep Tern's own command.

local EDITABLE: { [string]: boolean } = { terminal = true, agent = true }

-- POSIX sh, run by the new tab's shell. `tern` comes from PATH, else ~/.local/bin (where Tern installs it on the
-- Mac and on a remote host). A failed capture says so and waits for Enter instead of opening an empty buffer.
local function command_line(pane: number): string
	return table.concat({
		'f=$(mktemp "${TMPDIR:-/tmp}/tern-scrollback.XXXXXX") || exit 1',
		't=$(command -v tern || echo "$HOME/.local/bin/tern")',
		string.format(
			'if "$t" capture %d --scrollback >"$f"; then if command -v nvim >/dev/null 2>&1; then nvim + "$f"; else vim + "$f"; fi; else printf "scrollback-editor: tern capture %d failed; press Enter\\n"; read -r _; fi',
			pane,
			pane
		),
		'rm -f "$f"',
	}, "; ")
end

tern.override("open_scrollback", function(cx: WindowCx): boolean?
	local pane = cx.session:focused()
	if pane == nil then
		return false
	end
	local info = cx.session:pane(pane)
	if info == nil or not EDITABLE[info.kind or ""] then
		return false
	end
	local cwd = info.cwd
	cx.layout:new_tab({ cwd = if cwd ~= nil and cwd ~= "" then cwd else nil, command = command_line(pane) })
	return true
end)
