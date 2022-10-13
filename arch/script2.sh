#!/bin/bash

git clone https://github.com/pyenv/pyenv-virtualenv.git "$(pyenv root)/plugins/pyenv-virtualenv"

pyenv install 3.10.5
nvm i 16

npm i -g pnpm
pnpm i -g neovim yarn balzss/cli-typer
pip install pgcli
cargo install spotify-tui

pyenv virtualenv nvim
pyenv activate nvim
pip install pynvim debugpy
pyenv deactivate
pyenv global system

ln -s ~/.config/tmux/.tmux.conf ~/.tmux.conf
mkdir ~/.tmux
ln -s ~/.config/tmux/plugins ~/.tmux/plugins

mkdir ~/.icons
cp -r ~/.local/share/chezmoi/.script/oreo_spark_purple_cursors ~/.icons

sudo pacman -S docker docker-compose
sudo systemctl start docker.service
sudo systemctl enable docker.service
sudo groupadd docker
sudo usermod -aG docker "$USER"

yay -S ly
sudo chmod +x ~/.xinitrc
systemctl disable lightdm.service
systemctl enable ly.service

yay -Rns lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings

git clone https://github.com/LoneExile/nvim.git "$HOME/.config/nvim"

sudo fc-cache -f -v

## todo
# sudo echo "QT_QPA_PLATFORMTHEME='qt5ct'" > /etc/environment
# rclone config
# ssh-keygen -t rsa -b 4096 -C "Apinant"
# cat .ssh/id_rsa.pub
# setup docker
# xrandr -s 1920x1200
