#!/bin/bash
# Workspaces do AeroSpace na barra, por evento (sem polling).
# Lê os workspaces e as teclas da própria config do AeroSpace (alt-N → workspace <nome>), na ordem
# das teclas 1..9,0. Mostra só os que têm janelas e o focado; clique vai para o workspace.
# Eventos: o AeroSpace dispara aerospace_workspace_change / windows_on_spaces (exec-on-workspace-change)
# e window_focus (on-focus-changed) — ver aerospace/default-config.toml.

sketchybar --add event aerospace_workspace_change \
           --add event windows_on_spaces \
           --add event window_focus

bindings=$(aerospace config --get mode.main.binding --json 2>/dev/null)

while IFS=$'\t' read -r key ws; do
  [[ -n $ws ]] || continue
  space=(
    icon="$key"
    icon.font="$FONT:Bold:11.0"
    icon.color=$GREY
    icon.highlight_color=$BLUE
    icon.padding_left=8
    icon.padding_right=3
    label="$ws"
    label.font="$FONT:Semibold:12.0"
    label.color=$WHITE
    label.highlight_color=$BLUE
    label.padding_right=8
    background.color=$BACKGROUND_2
    background.corner_radius=6
    background.height=22
    background.drawing=off
    padding_left=2
    padding_right=2
    script="$PLUGIN_DIR/aerospace_space.sh"
    click_script="aerospace workspace $ws"
  )
  sketchybar --add item "space.$ws" left \
             --set "space.$ws" "${space[@]}" \
             --subscribe "space.$ws" aerospace_workspace_change windows_on_spaces window_focus system_woke
done < <(jq -r 'to_entries[] | select(.value | type == "string" and startswith("workspace "))
                | [(.key | sub("^alt-"; "")), (.value | sub("^workspace "; ""))] | @tsv' <<<"$bindings" |
         sort -t$'\t' -k1,1 | awk -F'\t' '$1 == "0" {last = $0; next} {print} END {if (last) print last}')

sketchybar --add bracket spaces '/space\..*/' \
           --set spaces background.color=$BACKGROUND_1 background.drawing=on background.corner_radius=8
