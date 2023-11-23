#!/bin/bash

alias zu='zap update -a && zap clean'

## Aliases section
alias cp="cp -i"                                                # Confirm before overwriting something
alias mv="mv -i"                                                # Confirm before overwriting something
alias df='df -h'                                                # Human-readable sizes
alias free='free -m'                                            # Show sizes in MB
alias top="btop"
alias :q="exit"
alias c="clear"
alias v="nvim"
# alias rcu="rclone sync -P ~/Downloads/gdrive/note/SecondBrain gdrive:'Note/Obsidian/SecondBrain'"
# alias rcd="rclone sync -P gdrive:'Note/Obsidian/SecondBrain' ~/Downloads/gdrive/note/SecondBrain"

alias treee="tree --no-permissions --no-filesize --no-user --no-time"

alias zel="zellij --layout ~/.config/zellij/layouts/clean.yaml"

## TMUX
alias t='tmux attach || tmux new-session'
alias ta="tmux attach -t"
alias tl="tmux ls"
alias tk="tmux kill-session -t"
alias tka="tmux kill-session -a"

# ssh
alias ssha='eval $(ssh-agent) && ssh-add'

# ls
# alias l='ls -lh'
# alias ll='ls -lah'
alias l='ls -la'
alias la='ls -A'
alias lm='ls -m'
alias lr='ls -R'
alias llg='ls -l --group-directories-first'

# Aliases Git
alias gcl='git clone'
alias gcld='git clone --depth'
alias gi='git init'
alias ga='git add'
alias gc='git commit -m'
alias gp='git pull'
alias gpa='git pull --recurse-submodules'
alias gf='git fetch'
alias gfa='git fetch --recurse-submodules'
alias gP='git push'
alias gs='git status'
alias gl='git log'
alias grl='git reflog'
alias glg="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)'"
alias glg1="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'"
alias gco='git checkout'
alias gw='git worktree'
alias gclb='git clone --bare'
# alias lg='lazygit'
# alias gitu='git add . && git commit && git push'

alias yp='yadm pull'
alias ypa='yadm pull --recurse-submodules'
alias yf='yadm fetch'
alias yfa='yadm fetch --recurse-submodules'
alias yadd= 'yadm add'

alias ld='lazydocker'

# alias awsx='aws --endpoint-url=http://localhost:4566'

alias k='kubectl'
alias kx='kubectx'
alias kn='kubens'
alias mk='minikube'

alias kga='kubectl get all'
alias kgaa='kubectl get all --all-namespaces'
alias kgn='kubectl get nodes'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kgrs='kubectl get replicasets'
alias kgnp='kubectl get networkpolicies'
alias kgc='kubectl get configmaps'
alias kgsa='kubectl get serviceaccounts'
alias kgsec='kubectl get secrets'
alias kgcr='kubectl get cronjobs'
alias kgj='kubectl get jobs'
alias kgns='kubectl get namespaces'
alias kgpv='kubectl get pv'
alias kgpvc='kubectl get pvc'
alias kgsc='kubectl get storageclass'

alias kdl='kubectl delete'
alias kdls='kubectl delete service'
alias kdld='kubectl delete deployment'
alias kdlp='kubectl delete pod'
alias kdlc='kubectl delete configmap'
alias kdlcr='kubectl delete cronjob'
alias kdlj='kubectl delete job'
alias kdlsec='kubectl delete secret'

# alias kgno='kubectl get nodes -o wide'
# alias kgpo='kubectl get pods -o wide'
# alias kgso='kubectl get services -o wide'
# alias kgdo='kubectl get deployments -o wide'
# alias kgrso='kubectl get replicasets -o wide'
# alias kgnoo='kubectl get nodes -o yaml'
# alias kgpoo='kubectl get pods -o yaml'
# alias kgsoo='kubectl get services -o yaml'
# alias kgdoo='kubectl get deployments -o yaml'
# alias kgrsoo='kubectl get replicasets -o yaml'
# alias kgnoy='kubectl get nodes -o json'
# alias kgpoy='kubectl get pods -o json'
# alias kgsoy='kubectl get services -o json'
# alias kgdoy='kubectl get deployments -o json'
# alias kgrsoy='kubectl get replicasets -o json'
# alias kgnl='kubectl get nodes --show-labels'
# alias kgpl='kubectl get pods --show-labels'
# alias kgsl='kubectl get services --show-labels'
# alias kgdl='kubectl get deployments --show-labels'
# alias kgrsl='kubectl get replicasets --show-labels'

# pyenv
alias py="python"
alias pa="pyenv activate"
alias pd="pyenv deactivate"
alias pv="pyenv versions"
alias pvir="pyenv virtualenv"
alias pl="pyenv local"
alias pg="pyenv global"

## Lazygit
lg()
{
    export LAZYGIT_NEW_DIR_FILE="$HOME/.lazygit/newdir"

    lazygit "$@"

    if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
        cd "$(cat $LAZYGIT_NEW_DIR_FILE)" || return
        rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
    fi
}

lgy() {
    cd ~ || return
    yadm enter lazygit
    cd - || return
}

ssh() {
    # Get the argument to ssh (assumes it's the last argument)
    local dest="${@: -1}"

    # If we are inside tmux, create a new window and rename it
    if [ -n "$TMUX" ]; then
        tmux new-window -n "$dest" "command ssh $@"
    else
        # If not inside tmux, just run the ssh command
        command ssh "$@"
    fi

    ## If we are inside tmux, rename the current window
    #     if [ -n "$TMUX" ]; then
    #         tmux rename-window "$dest"
    #     fi
    #     command ssh "$@"
}


# nnn file manager
# export NNN_FCOLORS='0000E6310000000000000000'
# export NNN_PLUG='v:imgview;d:dragdrop;p:preview-tui;'
export NNN_PLUG='v:imgview;p:preview-tui;'
export NNN_FIFO="/tmp/nnn.fifo"
export NNN_PREVIEWIMGPROG="catimg"
alias n="nnn -er"
