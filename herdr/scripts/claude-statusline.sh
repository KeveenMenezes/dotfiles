#!/bin/sh
# statusLine do Claude Code (recebe o JSON oficial no stdin):
#   - publica modelo e contexto do agent na sidebar do herdr (tokens $model / $ctx_*)
#   - guarda a cota do plano (rate_limits 5h / 7d) para a barra do herdr (claude-quota.sh)
#   - imprime uma linha compacta para o próprio Claude Code
export PATH="/opt/homebrew/bin:$PATH"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-quota"

IFS='	' read -r model ctx h5 h5r d7 <<EOF
$(jq -r '[
    (.model.display_name // "?"),
    ((.context_window.used_percentage // 0) | floor),
    (.rate_limits.five_hour.used_percentage // "-" | if type == "number" then floor else . end),
    (.rate_limits.five_hour.resets_at // "-"),
    (.rate_limits.seven_day.used_percentage // "-" | if type == "number" then floor else . end)
  ] | @tsv')
EOF

# a cota é da conta inteira: grava mesmo fora do herdr (ex.: terminal do VS Code)
if [ "$h5" != - ]; then
    mkdir -p "$(dirname "$CACHE")"
    printf '%s %s %s\n' "$h5" "$h5r" "$d7" > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
fi

# contexto vira um de três tokens, cada um com cor fixa na sidebar (o herdr não aceita cor vinda de script)
if [ -n "$HERDR_PANE_ID" ]; then
    if [ "$ctx" -ge 80 ]; then lvl=high; elif [ "$ctx" -ge 50 ]; then lvl=warn; else lvl=ok; fi
    set -- --token "model=$model"
    for l in ok warn high; do
        if [ "$l" = "$lvl" ]; then set -- "$@" --token "ctx_$l=ctx $ctx%"; else set -- "$@" --clear-token "ctx_$l"; fi
    done
    "${HERDR_BIN_PATH:-herdr}" pane report-metadata "$HERDR_PANE_ID" --source claude-statusline "$@" >/dev/null 2>&1 &
fi

# linha do Claude Code nas cores Prometheus (verde < 60% <= laranja < 85% <= vermelho)
c() { if [ "$1" -ge 85 ]; then printf '\033[38;2;244;71;71m'; elif [ "$1" -ge 60 ]; then printf '\033[38;2;255;158;59m'; else printf '\033[38;2;152;195;121m'; fi; }
DIM='\033[38;2;107;107;107m'; SKY='\033[38;2;0;208;255m'; R='\033[0m'

line=$(printf "${SKY}%s${R} ${DIM}ctx${R} $(c "$ctx")%s%%${R}" "$model" "$ctx")
if [ "$h5" != - ]; then
    left=$(( (h5r - $(date +%s)) / 60 )); [ "$left" -lt 0 ] && left=0
    line="$line $(printf "${DIM}· 5h${R} $(c "$h5")%s%%${R} ${DIM}(%dh%02dm)${R}" "$h5" $((left / 60)) $((left % 60)))"
fi
[ "$d7" != - ] && line="$line $(printf "${DIM}· 7d${R} $(c "$d7")%s%%${R}" "$d7")"
printf '%s\n' "$line"
