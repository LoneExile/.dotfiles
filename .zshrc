#!/bin/bash
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#     source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$USER.zsh"
fi

# Enabling the Zsh Completion System
autoload bashcompinit && bashcompinit
autoload -Uz compinit && compinit

eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(/usr/local/bin/brew shellenv)"

#A smarter cd command.
eval "$(zoxide init zsh)"

# Zap Plugin Manager
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

eval "$(github-copilot-cli alias -- "$0")"

# aws cli completion
complete -C '/usr/local/bin/aws_completer' aws

# dotnet tools
export PATH="$PATH:~/.dotnet/tools"
export DOTNET_CLI_TELEMETRY_OPTOUT=1


#NOTE:
# https://thevaluable.dev/zsh-completion-guide-examples/
