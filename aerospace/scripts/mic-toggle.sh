#!/bin/bash
# Alterna o microfone: mudo (volume de entrada 0) ↔ volume anterior. Avisa com uma notificação.
# AeroSpace: ctrl-alt-cmd-shift-m (o teclado manda isso pela tecla "mic" do layer Func).
STATE="${XDG_CACHE_HOME:-$HOME/.cache}/mic-volume"
mkdir -p "$(dirname "$STATE")"

cur=$(osascript -e 'input volume of (get volume settings)')
if [[ ${cur:-0} -gt 0 ]]; then
  echo "$cur" >"$STATE"
  osascript -e 'set volume input volume 0'
  msg="mudo"
else
  vol=$(cat "$STATE" 2>/dev/null)
  [[ ${vol:-0} -gt 0 ]] || vol=75
  osascript -e "set volume input volume $vol"
  msg="ligado ($vol%)"
fi
osascript -e "display notification \"Microfone $msg\" with title \"Microfone\""
