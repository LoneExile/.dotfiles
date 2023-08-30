#!/bin/bash

# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#     source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh"
fi

# Created by Zap installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
plug "$HOME/.config/zsh/aliases.zsh"
plug "$HOME/.config/zsh/options.zsh"
plug "$HOME/.config/zsh/keybindings.zsh"
plug "$HOME/.config/zsh/env.zsh"
plug "$HOME/.config/zsh/ely.zsh"
plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zsh-users/zsh-syntax-highlighting"
plug "zsh-users/zsh-completions"
plug "Aloxaf/fzf-tab"
plug "softmoth/zsh-vim-mode"
plug "zap-zsh/exa"
plug "Freed-Wu/fzf-tab-source"
# plug "zsh-users/zsh-history-substring-search"

# pnpm
export PNPM_HOME="/Users/$USER/Library/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
esac

alias code="/mnt/c/Users/ApinantU-suwantim/AppData/Local/Programs/Microsoft\ VS\ Code/bin/code" # --remote wsl+archlinux

# Load and initialise completion system
autoload -Uz compinit
autoload -U +X bashcompinit && bashcompinit
autoload -U +X compinit && compinit

# powerlevel10k
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme

# fzf
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

# aws cli completion
complete -C '/usr/bin//aws_completer' aws

# asdf
. ~/.asdf/asdf.sh
. ~/.asdf/completions/asdf.bash

eval "$(github-copilot-cli alias -- "$0")"
eval "$(zoxide init zsh)"

#
export PATH="/usr/bin:$PATH"

# dotnet tools
export PATH="$PATH:~/.dotnet/tools"
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
