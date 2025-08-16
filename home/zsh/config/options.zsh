## Options section
setopt correct                                                  # Auto correct mistakes
setopt extendedglob                                             # Extended globbing. Allows using regular expressions with *
setopt nocaseglob                                               # Case insensitive globbing
setopt rcexpandparam                                            # Array expension with parameters
setopt nocheckjobs                                              # Don't warn about running processes when exiting
setopt numericglobsort                                          # Sort filenames numerically when it makes sense
setopt nobeep                                                   # No beep
setopt appendhistory                                            # Immediately append history instead of overwriting
setopt histignorealldups                                        # If a new command is a duplicate, remove the older one
setopt autocd                                                   # if only directory path is entered, cd there.
setopt inc_append_history                                       # save commands are added to the history immediately, otherwise only when shell exits.
setopt histignorespace                                          # Don't save commands that start with space
unsetopt BEEP                                                   # beeping is annoying

# fine nvim path from 'which nvim'
nvim_path=$(which nvim)
export EDITOR="$nvim_path"
export VISUAL="$nvim_path"

# Color man pages
export LESS_TERMCAP_mb=$'\E[01;32m'
export LESS_TERMCAP_md=$'\E[01;32m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;47;34m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;36m'
export LESS=-R

# File and Dir colors for ls and other outputs
export LS_OPTIONS='--color=auto'
# eval "$(dircolors -b)"
alias ls='ls $LS_OPTIONS'

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'       # Case insensitive tab completion
zstyle ':completion:*' rehash true                              # automatically find new executables in path
# Speed up completions
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache
HISTFILE=~/.zhistory
HISTSIZE=10000
SAVEHIST=10000
WORDCHARS=${WORDCHARS//\/[&.;]}                                 # Don't consider certain characters part of the word
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"         # Colored completion (different colors for dirs/files/etc)

# -----------

: ${ZSH_DOTENV_FILE:=".env"}

#
# Source local '.env' file (if any).
#
source_env_file() {
  if [[ -f "${ZSH_DOTENV_FILE}" ]]; then
    >&2 echo "Auto-sourcing ${ZSH_DOTENV_FILE} file"
    source "${ZSH_DOTENV_FILE}"
  fi
}

# Hook our function so that it gets automatically executed whenever we `cd`
# See special `chpwd` hook function: https://zsh.sourceforge.io/Doc/Release/Functions.html
autoload -U add-zsh-hook
add-zsh-hook chpwd source_env_file
