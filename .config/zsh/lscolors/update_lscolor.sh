#!/usr/bin/env bash

repo_file="https://raw.githubusercontent.com/trapd00r/LS_COLORS/master/lscolors.sh"

## Download the file to $HOME/.config/zsh/lscolors/lsc.zsh
## check if have curl or wget
if [[ -x $(command -v curl) ]]; then
    curl -s "$repo_file" -o "$HOME/.config/zsh/lscolors/lsc.zsh"
elif [[ -x $(command -v wget) ]]; then
    wget -q "$repo_file" -O "$HOME/.config/zsh/lscolors/lsc.zsh"
else
    echo "No curl or wget found"
    exit 1
fi
