#!/bin/bash

FRONT_APP_SCRIPT='
ICON=$($HOME/.config/sketchybar/plugins/icon_map.sh "$INFO")
sketchybar --set $NAME icon="$ICON" label="$INFO"
'

aerospace=(
  script="$PLUGIN_DIR/aerospace.sh"
  icon.font="$FONT:Bold:16.0"
  label.drawing=off
  icon.width=30
  icon=$YABAI_GRID
  icon.color=$RED
  associated_display=active
)

front_app=(
  script="$FRONT_APP_SCRIPT"
  icon.drawing=on
  icon.font="sketchybar-app-font:Regular:16.0"
  icon.color=$BLUE
  padding_left=0
  label.color=$WHITE
  label.font="$FONT:Black:12.0"
  associated_display=active
)

sketchybar --add event window_focus            \
           --add event windows_on_spaces       \
           --add item aerospace left               \
           --set aerospace "${aerospace[@]}"           \
           --subscribe aerospace window_focus      \
                             windows_on_spaces \
                             mouse.clicked     \
                                               \
           --add item front_app left           \
           --set front_app "${front_app[@]}"   \
           --subscribe front_app front_app_switched

