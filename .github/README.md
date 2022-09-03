# dotfiles

Currenly using [Chezmoi](https://github.com/twpayne/chezmoi)


---

## script
```bash
sudo pacman -S archlinux-keyring
sudo pacman-key --populate

sudo pacman -Syu --needed --noconfirm - < packages-repository.txt

## nvm https://github.com/nvm-sh/nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

pyenv install 3.10.5
nvm i 18

## for neovim
yay -S codespell xsel actionlint-bin
cargo install stylua
npm install -g prettier neovim yarn eslint pnpm alex bash-language-server tree-sitter-cli
pnpm setup
pyenv virtualenv nvim
pyenv activate nvim
pip install isort black pynvim flake8 debugpy proselint pgcli beautysh ueberzug
pyenv deactivate
pyenv global system

## game cli
npm install -g balzss/cli-typer

## haskell tool stack (https://www.haskell.org/ghcup/)
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
# stack maybe dont have this above already have?
# wget -qO- https://get.haskellstack.org/ | sh
# Dockerfile linter
yay -S libgmp-static
git clone https://github.com/hadolint/hadolint \
&& cd hadolint \
&& stack install


## login
yay -S ly
chmod +x .xinitrc
systemctl disable lightdm.service
systemctl enable ly.service
# yay -Rns lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings

## set tmux (can't be in .config with tpm) :(
ln -s .config/tmux/.tmux.conf ./.tmux.conf
mkdir ~/.tmux
ln -s ~/.config/tmux/plugins ~/.tmux/plugins

## git stuff # TODO
chezmoi cd
git checkout chezmoi
git submodule init
git submodule update
# git clone --recurse-submodules

## Grub
bash ~/.local/share/chezmoi/.script/fallout-grub-theme/.install.sh
sudo grub-mkconfig -o /boot/grub/grub.cfg

## icons
mkdir ~/.icons
cp ~/.local/share/chezmoi/.script/oreo_spark_purple_cursors ~/.icons

## docker (need reboot)
sudo pacman -S docker docker-compose
sudo systemctl start docker.service
sudo systemctl enable docker.service
sudo usermod -aG docker $USER

## postgresql
yay -S postgresql-libs
pip install pgcli

## https://linux.die.net/man/1/fc-cache
sudo fc-cache -f -v 

## setup git
# sh-keygen -t rsa -b 2048 -C "<comment>"
# cat .ssh/id_rsa.pub

```


## package
`packages-repository.txt`
```bash
git
base-devel
yay

# WM needed
awesome-git
rofi-git
picom-jonaburg-git
polkit-gnome

# system tool 
upower
bluez
bluez-utils
xorg-setxkbmap
i3lock
xfce4-power-manager
playerctl

## produtive tool
flameshot
rclone
obsidian
input-remapper-git
bitwarden-cli

## programming language
go
rust
perl
ruby
pyenv
tk # pyenv dependency

## editor
neovim-nightly-bin
visual-studio-code-bin

## terminal
kitty
zsh-theme-powerlevel10k-git

## terminal tool
bat
wget
tree
ripgrep
fd
jq
fzf
xclip
lazygit
tmux
autorandr
gdu
xorg-xev
xdotool


## files handle
zip
nnn-nerd #nnn
advcpmv
nsxiv
zathura
zathura-pdf-mupdf
dragon-drop
glow # Render markdown

## rofi
rofi-emoji
noto-fonts-emoji
rofi-calc
rofi-greenclip
networkmanager-dmenu-git
dmenu

## theming
papirus-icon-theme
nitrogen
lxappearance
Mugshot
# lightdm
# thunar
# nerd-fonts-complete
#catppuccin-gtk-theme

## network
networkmanager
networkmanager-openvpn
network-manager-applet

## spotify
spotify-tui
spotifyd
sptlrx-bin
cli-visualizer

## discord
discord
betterdiscord-installer

## ocr tool
ocrdesktop
tesseract-data-eng
tesseract-data-tha

## audio
pipewire-jack
pipewire-alsa
pipewire-pulse
qjackctl
pulsemixer

## gui
brave-bin
qutebrowser-git

## programming
postgresql-libs
postman-bin

## dotnet
dotnet-runtime-bin
aspnet-runtime-bin
dotnet-sdk-bin
dotnet-host-bin
```

## qt theme

edit this file `/etc/environment` and add this line then reboot 
lunch qt5ct to change theme [set Q5](https://youtu.be/qU6iDx4xB5o)
```
QT_QPA_PLATFORMTHEME="qt5ct"
```

install theme [more](https://wiki.archlinux.org/title/qt#Styles_in_Qt_5)
```bash
yay -S breeze # OR lightly-git
```
