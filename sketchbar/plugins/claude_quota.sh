#!/bin/bash
# Cota do plano Claude na barra: reaproveita o segmento da barra do herdr (herdr/scripts/claude-quota.sh).
out=$("$HOME/.config/herdr/scripts/claude-quota.sh" 2>/dev/null)
if [[ -n $out ]]; then
  sketchybar --set "$NAME" drawing=on label="$out"
else
  sketchybar --set "$NAME" drawing=off
fi
