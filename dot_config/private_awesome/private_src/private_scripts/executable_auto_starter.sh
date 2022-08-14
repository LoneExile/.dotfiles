#!/bin/bash

## if not using autorandr
# if [[ $(xrandr -q | grep "DP-2-1 connected") ]]; then
#  xrandr --output eDP-1 --mode 1920x1080 --rate 60 --primary --output DP-2-3 --left-of eDP-1 --mode 1920x1080 --rate 60 --output DP-2-1 --left-of DP-2-3 --mode 1920x1080 --rate 60
# else
#  xrandr --output eDP-1 --mode 1920x1080 --rate 60 --primary
# fi

[ -n "$(pidof picom)" ] || picom --experimental-backends &
[ -n "$(pidof polkit-gnome-authentication-agent-1)" ] || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
[ -n "$(pidof flameshot)" ] || flameshot &
[ -n "$(pidof input-remapper-control)" ] || input-remapper-control --command autoload &
[ -n "$(pidof xfce4-power-manager)" ] || xfce4-power-manager &
# [ -n "$(pidof rclone)" ] || rclone mount --vfs-cache-mode full --daemon gdrive: ~/Downloads/gdrive/usu
[ -n "$(pidof spotifyd)" ] || spotifyd &
[ -n "$(pidof greenclip)" ] || greenclip daemon &

nitrogen --restore
