#!/bin/bash

window_state() {
  source "$HOME/.config/sketchybar/colors.sh"
  source "$HOME/.config/sketchybar/icons.sh"

  # Get current workspace
  CURRENT_WORKSPACE=$(aerospace list-workspaces --focused)
  
  # Get window info (aerospace doesn't have the same detailed window state as yabai)
  # We'll focus on basic window management
  FLOATING_WINDOWS=$(aerospace list-windows --workspace focused --format '%{window-id}' | wc -l)
  
  args=()
  
  # Since aerospace doesn't have stack/zoom modes like yabai, 
  # we'll use a simpler approach based on workspace state
  if [ "$FLOATING_WINDOWS" -gt 0 ]; then
    args+=(--set $NAME icon=$YABAI_GRID icon.color=$RED label.drawing=off)
  else
    args+=(--set $NAME icon=$YABAI_FLOAT icon.color=$ORANGE label.drawing=off)
  fi

  sketchybar -m "${args[@]}"
}

windows_on_spaces() {
  # Update workspaces 1-6 explicitly
  for workspace in {1..6}; do
    icon_strip=" "
    # Get apps in this workspace
    apps=$(aerospace list-windows --workspace "$workspace" --format '%{app-name}' 2>/dev/null | sort -u)
    
    if [ -n "$apps" ]; then
      while IFS= read -r app; do
        if [ -n "$app" ]; then
          icon_strip+=" $($HOME/.config/sketchybar/plugins/icon_map.sh "$app")"
        fi
      done <<< "$apps"
    fi
    
    # Only show label if there are apps
    if [ "$icon_strip" != " " ]; then
      sketchybar --set space.$workspace label="$icon_strip" label.drawing=on
    else
      sketchybar --set space.$workspace label="" label.drawing=off
    fi
  done
}

mouse_clicked() {
  # aerospace doesn't have a direct toggle float command
  # but we can move window to floating workspace or back
  echo "Aerospace doesn't support toggle float like yabai"
  window_state
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked
  ;;
  "forced") exit 0
  ;;
  "window_focus") window_state 
  ;;
  "windows_on_spaces") windows_on_spaces
  ;;
esac