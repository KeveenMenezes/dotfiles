#!/bin/bash
# Atualiza herdr.agents e herdr.task a partir do herdr (uma chamada para cada lista).
source "$HOME/.config/sketchybar/colors.sh"
HERDR=/opt/homebrew/bin/herdr
JQ=/opt/homebrew/bin/jq

agents=$("$HERDR" agent list 2>/dev/null) || agents=""
if [[ -z $agents ]]; then
  sketchybar --set herdr.agents drawing=off --set herdr.task drawing=off
  exit 0
fi

read -r blocked done working < <("$JQ" -r '[.result.agents[]?.agent_status] |
  [(map(select(. == "blocked")) | length), (map(select(. == "done")) | length), (map(select(. == "working")) | length)] | @tsv' <<<"$agents")

label=""
((blocked)) && label+="⚠ $blocked  "
((done)) && label+="✓ $done  "
((working)) && label+="◐ $working"
label=${label%  }
[[ -n $label ]] || label="ocioso"

if ((blocked)); then color=$RED
elif ((done)); then color=$GREEN
elif ((working)); then color=$YELLOW
else color=$WHITE; fi

task=$("$HERDR" workspace list 2>/dev/null | "$JQ" -r '.result.workspaces[]? | select(.focused) | .label')

sketchybar --set herdr.agents drawing=on label="$label" icon.color="$color" label.color="$color" \
           --set herdr.task drawing="$([[ -n $task ]] && echo on || echo off)" label="$task"
