#! /bin/sh

chosen=$(printf "📋  Clipboard\n📡  Networks\n🚀  Run\n♾️  Calculator\n😀  Emoji\n💤  Power Menu" | rofi -dmenu -i -theme-str '@import "~/.config/rofi/utility/power.rasi"' )

case "$chosen" in
	"💤  Power Menu") ~/.config/rofi/utility/powermenu/powermenu.sh ;;
	"🚀  Run") rofi -show run ;;
	"♾️  Calculator") rofi -show calc -modi calc -no-show-match -no-sort ;;
	"😀  Emoji") rofi -modi emoji -show emoji -emoji-format '{emoji} {name} / {keywords}' ;; # -emoji-mode copy
	"📡  Networks") networkmanager_dmenu ;;
  "📋  Clipboard") rofi -modi "clipboard:greenclip print" -show clipboard -run-command '{cmd}' ;;
	*) exit 1 ;;
esac

# rofi -show keys -i -theme-str '@import "~/.config/rofi/utility/run.rasi"'
