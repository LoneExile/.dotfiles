#!/bin/bash

# update and sync package
sudo pacman -Syyu

# node version management
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

# pyenv
curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash

# install rust
curl --proto '=https' --tlsv1.3 https://sh.rustup.rs -sSf | sh

# sound diver
sudo pacman -S git base-devel yay manjaro-pipewire

# install grub theme
wget -O - https://github.com/shvchk/fallout-grub-theme/raw/master/install.sh | bash

# install package
sudo pacman -Syu --needed --noconfirm - < packages.txt

# apply dotfiles
sh -c "$(curl -fsLS https://chezmoi.io/get)" -- init --apply LoneExile

# make zsh default shell
chsh -s "$(which zsh)"

# sync time
timedatectl set-ntp yes

# source zsh
exec zsh
