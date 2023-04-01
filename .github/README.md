# Dotfiles MacOS

Currenly using [Chezmoi](https://github.com/twpayne/chezmoi)

This branch for MacOS

---

```bash
# install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install bat btop chezmoi docker fd fzf cmake gcc git jq lazygit nnn ripgrep\
tmux tree tree-sitter wget gdu gnupg unzip rclone

brew install romkatv/powerlevel10k/powerlevel10k
brew install ruby go luarocks perl rust dotnet
brew install nvm pyenv pyenv-virtualenv
brew install neovim --HEAD

brew install koekeishiya/formulae/yabai
brew services start yabai
brew install koekeishiya/formulae/skhd
brew services start skhd

brew install --cask appcleaner iina kap brave-browser kitty discord numi obsidian\
qbittorrent mtmr spotify karabiner-elements alfred steam glow

brew tap homebrew/cask-fonts && brew install --cask font-jetbrains-mono-nerd-font


npm install -g neovim
pip install pynvim

# from my dotfiles
# ln -s .config/zsh/.zshrc ~/.zshrc
```

<http://www.bresink.com/osx/TinkerTool.html>

—————————————————————

Git

```bash

ssh-keygen -t rsa -b 4096 -C "" 

git config --global user.name ""

git config --global user.email ""
```

```bash
# chezmoi location
cm add karabiner kitty zsh/.zshrc
cm add .gitconfig .p10k.zsh .skhdrc .yabairc .zprofile
```

```perl
# uninstall Module in perl
cpanm --uninstall Module::Name
```

---

## TODO

add `.Keyboard Layouts` to `/Library/Keyboard Layouts`

add `MTMR` to `/Users/<your pc name>/Library/Application Support/MTMR/`

add `karabiner` to `~/.config/karabiner/assets/complex_modifications/`
`Windows shortcuts on macOS`

### Resource

[SketchyBar](https://github.com/FelixKratz/SketchyBar)

[ke-complex](https://ke-complex-modifications.pqrs.org/?q=vi%20mode)
