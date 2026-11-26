#!/bin/bash
# Um item space.<workspace>: destaca o focado, mostra os que têm janelas, esconde os vazios.
ws=${NAME#space.}
focused=${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}

if [[ $ws == "$focused" ]]; then
  sketchybar --set "$NAME" drawing=on icon.highlight=on label.highlight=on background.drawing=on
  exit 0
fi

count=$(aerospace list-windows --workspace "$ws" --count 2>/dev/null || echo 0)
if [[ ${count:-0} -gt 0 ]]; then
  sketchybar --set "$NAME" drawing=on icon.highlight=off label.highlight=off background.drawing=off
else
  sketchybar --set "$NAME" drawing=off
fi
