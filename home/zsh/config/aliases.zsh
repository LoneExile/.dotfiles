## Aliases section
alias cp="cp -i"                                                # Confirm before overwriting something
alias mv="mv -i"                                                # Confirm before overwriting something
alias df='df -h'                                                # Human-readable sizes
alias free='free -m'                                            # Show sizes in MB
alias top="btop"
alias :q="exit"
alias c="clear"
alias v="nvim"
alias vx="$HOME/.dotfiles/nvim-wrapper"
alias gdu="gdu-go"
alias ld="lazydocker"

alias bu='brew update && brew upgrade && brew cleanup && brew doctor'
alias zu='zap update all && zap clean'

alias k=kubectl
alias kx='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'
alias tf='terraform'
alias tg='terragrunt'

alias mk='minikube'

## TMUX
alias t='tmux attach || tmux new-session'
alias ta="tmux attach -t"
alias tl="tmux ls"
alias tk="tmux kill-session -t"
alias tka="tmux kill-session -a"

# ssh
alias ssha='eval $(ssh-agent) && ssh-add'

# ls
alias l='ls -lh'
# alias ll='ls -lah'
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

## gh auth login
## gh extension install github/gh-copilot
## gh extension upgrade gh-copilot

alias avante='nvim -c "lua vim.defer_fn(function()require(\"avante.api\").zen_mode()end, 100)"'

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

dk() {
    if [ "$1" = "start" ]; then
        colima start
        sudo ln -s /Users/$USER/.colima/default/docker.sock /var/run/docker.sock
    elif [ "$1" = "stop" ]; then
        colima stop
        sudo rm /var/run/docker.sock
    elif [ "$1" = "restart" ]; then
        colima restart
    elif [ "$1" = "status" ]; then
        colima status
    else
        echo "Usage: d [start|stop|restart|status]"
    fi
}

pkgup() {
    # pnpm install -g @gsong/ccmcp
    # pnpm install -g @anthropic-ai/claude-code
    # pnpm install -g @dbml/cli
    # pnpm install -g @fission-ai/openspec
    # pnpm install -g @github/copilot
    # pnpm install -g @google/gemini-cli
    # pnpm install -g get-graphql-schema
    # pnpm install -g mcp-hub
    # pnpm install -g neovim
    # pnpm i -g opencode-ai@latest

    # pnpm self-update
    pnpm update -g --latest
    gh extension upgrade --all
    # zu
}
