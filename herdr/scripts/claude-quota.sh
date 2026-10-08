#!/bin/sh
# Barra do herdr (tab_bar_right): cota do plano Claude gravada pelo claude-statusline.sh.
# Some quando não há dado ou quando a janela de 5h já resetou. O herdr remove cores daqui.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-quota"
[ -r "$CACHE" ] || exit 0
read -r h5 h5r d7 < "$CACHE"

left=$(( h5r - $(date +%s) ))
[ "$left" -gt 0 ] || exit 0

out=$(printf '\363\260\232\251 5h %s%% \342\206\273 %dh%02dm' "$h5" $((left / 3600)) $((left % 3600 / 60)))
[ "$d7" != - ] && out="$out · 7d $d7%"
printf '%s\n' "$out"
