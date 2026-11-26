#!/bin/bash
# Clique em herdr.agents: traz o Ghostty e foca o agente que mais precisa de você
# (bloqueado primeiro, depois o que terminou); sem nenhum, só abre o Ghostty.
HERDR=/opt/homebrew/bin/herdr
JQ=/opt/homebrew/bin/jq

target=$("$HERDR" agent list 2>/dev/null | "$JQ" -r '
  [.result.agents[]? | select(.agent_status == "blocked")] + [.result.agents[]? | select(.agent_status == "done")]
  | first | .pane_id // empty')

open -a Ghostty
[[ -n $target ]] && "$HERDR" agent focus "$target" >/dev/null 2>&1
sketchybar --trigger herdr_update
