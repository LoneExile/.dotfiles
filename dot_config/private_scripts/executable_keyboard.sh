#!/usr/bin/env bash

LAYOUT=$(setxkbmap -query | awk '/layout/ {print $2}')

if [[ "$LAYOUT" == "th" ]]; then
   setxkbmap us
else
   setxkbmap th
fi
