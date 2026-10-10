# omp, in a Tern pane: ask Tern for paste events while omp runs (home/linux/agent.nix puts this in ~/.zshenv; omp-image-paste_test.sh tests this file).
#
# Why. Tern sends a program the clipboard's data, and not only its text or a path, when the program turns on the paste-events mode of
# kitty's clipboard protocol (CSI ? 5522 h). omp 18.8.7, 18.8.8 and 18.8.9 never do (measured: no such byte on the wire in any of
# them). The code that should write it is a start listener of the terminal UI (modes/controllers/input-controller.ts:894-895 of
# oh-my-pi v18.8.9); my reading is that it is added after the UI started, so it never runs. Without the mode, Tern types the Mac
# path of a copied file, or pastes nothing for an image-only clipboard, and omp on the VM answers "Image not found at <that path>"
# or "Clipboard is empty". With the mode on, omp's own paste code (which prefers image/png) attaches the image, also when the
# clipboard holds a file URL next to the PNG (measured with a clipboard made to look like that, not one copied by Vorssaint).
#
# Rules. Only a real terminal in a Tern pane (stdin and stdout are ttys, TERM_PROGRAM is tern): a pipe, a file, `omp -p | less`,
# ssh from another terminal and a script get no escape byte. The mode is reset when omp ends, whatever the way: the exit, an error
# exit, Ctrl-C (a shell that has no job control, such as `zsh -l -c omp`, gets the SIGINT too, and would die before an `always`
# block ran: the INT trap keeps it alive until omp is gone, and the EXIT trap, local to the function, resets the mode). omp's exit
# status is the function's. Every argument goes through, so `omp update` and `omp --version` are unchanged.
#
# It is a function of ~/.zshenv, which every zsh reads. Measured on the VM and on the Mac: a Tern pane runs `zsh -l` (an interactive login
# shell) and omp is a child of it, so a typed `omp` calls this function; ~/.zshenv also covers a `zsh -c omp` (no ~/.zshrc there). A zsh
# that was already running does not have it until it is replaced (`exec zsh`).
omp() {
  if [[ -t 0 && -t 1 && $TERM_PROGRAM == tern ]]; then
    emulate -L zsh
    setopt local_traps
    local rc
    trap 'printf "\e[?5522l"' EXIT
    trap : INT
    printf '\e[?5522h'
    command omp "$@"
    rc=$?
    return $rc
  fi
  command omp "$@"
}
