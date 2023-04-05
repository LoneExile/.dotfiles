#!/bin/bash
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#     source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(/usr/local/bin/brew shellenv)"

alias brew='arch -arm64e /opt/homebrew/bin/brew'
alias ibrew='arch -x86_64 /usr/local/bin/brew'
alias bu='brew update && brew upgrade && ibrew update && ibrew upgrade'
alias bua='brew update && brew upgrade && ibrew update && ibrew upgrade && zap update -a'
alias bc='brew cleanup && brew autoremove && ibrew cleanup && ibrew autoremove'
alias wu='brew upgrade --cask wezterm-nightly --no-quarantine --greedy-latest'

# Enabling the Zsh Completion System
autoload -U compinit; compinit

[ -f "$HOME/.local/share/zap/zap.zsh" ] && source "$HOME/.local/share/zap/zap.zsh"

plug "/opt/homebrew/opt/asdf/libexec/asdf.sh"
plug "$HOME/.config/zsh/aliases.zsh"
plug "$HOME/.config/zsh/options.zsh"
plug "$HOME/.config/zsh/keybindings.zsh"

plug "romkatv/powerlevel10k"
plug "zsh-users/zsh-autosuggestions"
plug "zsh-users/zsh-syntax-highlighting"
plug "zsh-users/zsh-completions"
plug "Aloxaf/fzf-tab"
plug "softmoth/zsh-vim-mode"
plug "zap-zsh/supercharge"
plug "zap-zsh/exa"
plug "Freed-Wu/fzf-tab-source"
plug "zsh-users/zsh-history-substring-search"

# pnpm
export PNPM_HOME="/Users/$USER/Library/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# add PATH for local binaries
export PATH=$PATH:$HOME/.local/bin

# FZF
[ -f ~/.fzf.zsh ] && source "$HOME/.fzf.zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source "$HOME/.p10k.zsh"

#NOTE:
# https://thevaluable.dev/zsh-completion-guide-examples/
