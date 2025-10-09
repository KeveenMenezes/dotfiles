#!/bin/bash

# Get workspace ID from script argument or NAME
WORKSPACE_ID="${1:-${NAME##*.}}"

update() {
  # Não fazer nada - deixar o update_spaces.sh (chamado pelo aerospace_events.sh) gerenciar tudo
  # Isso evita conflitos entre os dois processos
  :
}

mouse_clicked() {
  if [ "$BUTTON" = "right" ]; then
    # aerospace doesn't support destroying workspaces
    aerospace close-all-windows-but-current --workspace "$WORKSPACE_ID"
    # Trigger update via aerospace_events
    sleep 0.1
  else
    aerospace workspace "$WORKSPACE_ID"
    # Trigger update via aerospace_events
    sleep 0.1
  fi
}

case "$SENDER" in
  "mouse.clicked") mouse_clicked
  ;;
  *) update
  ;;
esac