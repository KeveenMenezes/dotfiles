#!/usr/bin/env bash
# Evento do herdr (agente mudou de estado / workspace focada mudou) → atualiza a sketchybar na hora.
[[ -x /opt/homebrew/bin/sketchybar ]] && /opt/homebrew/bin/sketchybar --trigger herdr_update >/dev/null 2>&1
exit 0
