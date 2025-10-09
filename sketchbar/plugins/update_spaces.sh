#!/bin/bash

# Get current focused workspace
FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null)

# Update all 6 workspaces
for i in {1..6}; do
  # Check if workspace has windows
  WINDOWS_COUNT=$(aerospace list-windows --workspace "$i" 2>/dev/null | wc -l | tr -d ' ')
  
  # Check if this workspace is focused
  if [ "$i" = "$FOCUSED" ]; then
    SELECTED="on"
    WIDTH="0"  # Hide icon for focused workspace
  else
    SELECTED="off"
    WIDTH="dynamic"  # Show icon for unfocused workspace
  fi
  
  # IMPORTANTE: Ocultar workspace se estiver vazio E não estiver focado
  if [ "$WINDOWS_COUNT" = "0" ] && [ "$SELECTED" = "off" ]; then
    sketchybar --set space.$i drawing=off
    continue
  fi
  
  # Mostrar workspace se tiver janelas OU estiver focado
  sketchybar --set space.$i drawing=on icon.highlight=$SELECTED
  
  # Get apps in this workspace and build icon strip
  icon_strip=" "
  if [ "$WINDOWS_COUNT" -gt "0" ]; then
    apps=$(aerospace list-windows --workspace "$i" --format '%{app-name}' 2>/dev/null | sort -u)
    
    if [ -n "$apps" ]; then
      while IFS= read -r app; do
        if [ -n "$app" ]; then
          icon_strip+=" $($HOME/.config/sketchybar/plugins/icon_map.sh "$app")"
        fi
      done <<< "$apps"
      sketchybar --set space.$i label="$icon_strip" label.drawing=on label.width=$WIDTH
    else
      sketchybar --set space.$i label="" label.drawing=off label.width=$WIDTH
    fi
  else
    sketchybar --set space.$i label="" label.drawing=off label.width=$WIDTH
  fi
done
