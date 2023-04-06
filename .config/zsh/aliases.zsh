## Alias section
alias cp="cp -i"                                                # Confirm before overwriting something
alias mv="mv -i"                                                # Confirm before overwriting something
alias top="btop"
alias df='df -h'                                                # Human-readable sizes
alias free='free -m'                                            # Show sizes in MB
alias :q="exit"
alias c="clear"
alias v="nvim"
alias rcu="rclone sync -P ~/Downloads/gdrive/note/SecondBrain gdrive:'Note/Obsidian/SecondBrain'"
alias rcd="rclone sync -P gdrive:'Note/Obsidian/SecondBrain' ~/Downloads/gdrive/note/SecondBrain"

# ls
alias l='ls -lh'
# alias ll='ls -lah'
alias la='ls -A'
alias lm='ls -m'
alias lr='ls -R'
alias llg='ls -l --group-directories-first'

# git
alias gcl='git clone'
alias gi='git init'
alias ga='git add'
alias gc='git commit -m'
alias gp='git pull'
alias gP='git push'
alias gs='git status'
alias gl='git log'
alias grl='git reflog'
alias glg="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)'"
alias glg1="git log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(bold yellow)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'"
alias gf='git fetch'
alias gco='git checkout'
alias gw='git worktree'
alias gclb='git clone --bare'
alias ld='lazydocker'
# alias lg='lazygit'
# alias gitu='git add . && git commit && git push'
# alias gcl='git clone --depth 1'


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

# nnn file manager
# export NNN_FCOLORS='0000E6310000000000000000'
# export NNN_PLUG='v:imgview;d:dragdrop;p:preview-tui;'
export NNN_FIFO="/tmp/nnn.fifo"
alias n="nnn -er"