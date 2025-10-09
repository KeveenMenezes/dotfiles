#!/bin/bash

# Trigger the brew_udpate event when brew update or upgrade is run from cmdline
# e.g. via function in .zshrc

brew=(
  icon=􀐛
  icon.padding_left=10
  label=?
  label.padding_right=10
  padding_right=20
  padding_left=15
  script="$PLUGIN_DIR/brew.sh"
  background.color=$BACKGROUND_1
  background.border_color=$BACKGROUND_2
  background.border_width=0
)

sketchybar --add event brew_update \
           --add item brew q \
           --set brew "${brew[@]}" \
           --subscribe brew brew_update

