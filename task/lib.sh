#!/usr/bin/env bash
# Funções compartilhadas pelo `task` e pelas receitas de layout (task/layouts/*.sh).
# Só fala com o herdr pelo CLI (JSON); nenhuma regra de empresa aqui.

TASK_HERDR="${HERDR_BIN_PATH:-herdr}"

die() { printf 'task: %s\n' "$*" >&2; exit 1; }
info() { printf '\033[38;2;41;184;219m▸\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[38;2;255;192;102m!\033[0m %s\n' "$*" >&2; }

in_herdr() { [[ ${HERDR_ENV:-} == 1 ]] || [[ -S ${HERDR_SOCKET_PATH:-$HOME/.config/herdr/herdr.sock} ]]; }

hj() { "$TASK_HERDR" "$@" 2>/dev/null; }

# ── workspaces / tabs / panes ────────────────────────────────────────────────
ws_find() { # label -> workspace_id
    hj workspace list | jq -r --arg l "$1" '.result.workspaces[] | select(.label == $l) | .workspace_id' | head -1
}

ws_create() { # cwd label -> "ws tab pane"
    hj workspace create --cwd "$1" --label "$2" --no-focus |
        jq -r '.result | "\(.workspace.workspace_id) \(.tab.tab_id) \(.root_pane.pane_id)"'
}

tab_create() { # ws cwd label -> "tab pane"
    hj tab create --workspace "$1" --cwd "$2" --label "$3" --no-focus |
        jq -r '.result | "\(.tab.tab_id) \(.root_pane.pane_id)"'
}

pane_split() { # pane right|down cwd [ratio] -> new pane id
    local args=(pane split --pane "$1" --direction "$2" --cwd "$3" --no-focus)
    [[ -n ${4:-} ]] && args+=(--ratio "$4")
    hj "${args[@]}" | jq -r '.result.pane.pane_id'
}

pane_run() { hj pane run "$1" "$2" >/dev/null; }     # executa (texto + Enter)
pane_type() { hj pane send-text "$1" "$2" >/dev/null; } # só digita, você decide quando rodar
pane_label() { hj pane rename "$1" "$2" >/dev/null; }

agent_start() { # pane name [args do agente...]
    local pane=$1 name=$2
    shift 2
    local kind="${TASK_AGENT_KIND:-claude}" n=$name i=2
    while hj agent get "$n" | jq -e '.result' >/dev/null 2>&1; do n="$name-$i"; i=$((i + 1)); done
    if (($#)); then
        hj agent start "$n" --kind "$kind" --pane "$pane" --timeout 60000 -- "$@" >/dev/null
    else
        hj agent start "$n" --kind "$kind" --pane "$pane" --timeout 60000 >/dev/null
    fi
}

# ── git ──────────────────────────────────────────────────────────────────────
git_main_of() { # caminho de uma worktree -> caminho do repositório principal
    git -C "$1" worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0, 10); exit}'
}

git_default_base() { # repo principal -> branch padrão do origin (develop, main…)
    local b
    b=$(git -C "$1" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) && { echo "${b#origin/}"; return; }
    for b in develop main master; do
        git -C "$1" show-ref --verify --quiet "refs/remotes/origin/$b" && { echo "$b"; return; }
    done
    echo main
}

ticket_of() { # branch -> ticket (primeiro número de 3 a 5 dígitos entre separadores)
    sed -nE 's#(^|.*[/_-])([0-9]{3,5})([/_-].*|$)#\2#p' <<<"$1" | head -1
}

slugify() { # "Ação de Teste" -> acao-de-teste (NFD + remove marcas; o iconv do macOS translitera mal)
    perl -CSA -MUnicode::Normalize -e '
        my $s = NFD(lc join(" ", @ARGV)); $s =~ s/\pM//g; $s =~ s/[^a-z0-9]+/-/g; $s =~ s/^-+|-+$//g;
        $s = substr($s, 0, 40); $s =~ s/-+$//; print $s' -- "$1"
}
