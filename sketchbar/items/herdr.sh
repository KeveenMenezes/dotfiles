#!/bin/bash
# Itens do herdr e do Claude na barra (lado direito):
#   herdr.task    workspace focada no herdr (tarefa atual)
#   herdr.agents  ⚠ bloqueados · ✓ prontos · ◐ trabalhando; clique foca o primeiro que precisa de você
#   claude.quota  cota do plano (5h / 7d), do cache gravado pelo statusLine do Claude Code
# Atualização: o plugin keveen.workflow do herdr dispara `herdr_update` quando a workspace focada
# muda; o estado dos agentes é lido a cada 10 s (uma chamada a `herdr agent list`).

sketchybar --add event herdr_update

herdr_agents=(
  icon=◆
  icon.font="$FONT:Bold:12.0"
  label.font="JetBrainsMono Nerd Font:Bold:12.0"
  update_freq=10
  script="$PLUGIN_DIR/herdr.sh"
  click_script="$PLUGIN_DIR/herdr_click.sh"
)

herdr_task=(
  icon.drawing=off
  label.font="$FONT:Semibold:12.0"
  label.color=$WHITE
  click_script="open -a Ghostty"
)

claude_quota=(
  icon.drawing=off
  label.font="JetBrainsMono Nerd Font:Regular:11.0"
  label.color=$WHITE
  update_freq=60
  script="$PLUGIN_DIR/claude_quota.sh"
)

sketchybar --add item herdr.agents right \
           --set herdr.agents "${herdr_agents[@]}" \
           --subscribe herdr.agents herdr_update system_woke \
           --add item herdr.task right \
           --set herdr.task "${herdr_task[@]}" \
           --add item claude.quota right \
           --set claude.quota "${claude_quota[@]}" \
           --subscribe claude.quota system_woke
