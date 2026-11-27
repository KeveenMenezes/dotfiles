#!/usr/bin/env bash
# Foca o agente que mais precisa de você: primeiro o bloqueado há mais tempo (pedindo aprovação ou
# respondendo pergunta), depois o que terminou há mais tempo e você ainda não viu (done).
# Substitui o open_notification_target (prefix+o), que só age sobre um toast do herdr visível na
# tela — e aqui as notificações vão para o macOS ([ui.toast] delivery = "terminal").
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
export PATH="/opt/homebrew/bin:$PATH"

target=$("$herdr" agent list | jq -r '
  [.result.agents[] | select(.focused | not) | select(.agent_status == "blocked" or .agent_status == "done")]
  | sort_by((if .agent_status == "blocked" then 0 else 1 end), .state_change_seq)
  | first | .pane_id // empty')

if [[ -n $target ]]; then
    exec "$herdr" agent focus "$target" >/dev/null
fi
"$herdr" notification show "Nenhum agente esperando" --body "nenhum bloqueado nem pronto sem ver" --sound none >/dev/null
