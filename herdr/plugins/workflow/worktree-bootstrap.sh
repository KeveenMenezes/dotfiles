#!/usr/bin/env bash
# worktree.created: leva para a worktree nova os arquivos locais que o git ignora e que o
# projeto precisa para rodar (.env, .envrc, *.local, settings.local.json do Claude…).
# Só copia o que existe na worktree principal e ainda não existe na nova; nunca sobrescreve.
#
#   evento do herdr (worktree.created):  sem argumentos, lê HERDR_PLUGIN_EVENT_JSON
#   chamada direta (bin/task):            worktree-bootstrap.sh <worktree-nova>
set -uo pipefail
export PATH="/opt/homebrew/bin:$PATH"

log() { printf '[worktree-bootstrap] %s\n' "$*" >&2; }

new="${1:-}"
if [[ -z $new ]]; then
    event="${HERDR_PLUGIN_EVENT_JSON:-}"
    [[ -n $event ]] || { log "sem HERDR_PLUGIN_EVENT_JSON"; exit 0; }
    # o caminho da worktree nova: primeiro campo "path" que seja um diretório git
    while read -r p; do
        if [[ -d $p ]] && git -C "$p" rev-parse --is-inside-work-tree >/dev/null 2>&1; then new=$p; break; fi
    done < <(jq -r '[.. | objects | (.path?, .worktree_path?, .checkout_path?, .cwd?) | strings] | unique[]' <<<"$event" 2>/dev/null)
    [[ -n $new ]] || { log "não achei o caminho da worktree no evento: $event"; exit 0; }
fi

# a worktree principal é a primeira da lista do git
main=$(git -C "$new" worktree list --porcelain | awk '/^worktree /{print substr($0, 10); exit}')
[[ -n $main && $main != "$new" ]] || { log "worktree principal não encontrada para $new"; exit 0; }

copied=0
while IFS= read -r rel; do
    base=${rel##*/}
    [[ $base =~ \.(example|sample|template)$ ]] && continue
    [[ $base =~ ^(\.env(\..+)?|\.envrc|.*\.local(\..+)?|settings\.local\.json|\.lazysql\.toml)$ ]] || continue
    [[ -f $main/$rel && ! -e $new/$rel ]] || continue
    mkdir -p "$new/$(dirname "$rel")"
    cp -p "$main/$rel" "$new/$rel" && copied=$((copied + 1)) && log "copiado: $rel"
done < <(git -C "$main" ls-files --others --ignored --exclude-standard 2>/dev/null |
    grep -v -E '(^|/)(node_modules|bin|obj|dist|build|\.venv|vendor|target)/')

if [[ -f $new/.envrc ]] && command -v direnv >/dev/null; then
    direnv allow "$new" && log "direnv allow em $new"
fi

log "$copied arquivo(s) copiado(s) de $main para $new"
