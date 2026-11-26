#!/usr/bin/env bash
# Abre o popup de preview do GitHub.
#   (sem args)  link clicado (HERDR_PLUGIN_CLICKED_URL)
#   --current   PR do branch da pane focada (cwd vem do contexto do herdr)
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
ctx="${HERDR_PLUGIN_CONTEXT_JSON:-}"
[[ -n $ctx ]] || ctx='{}'
args=(plugin pane open --plugin keveen.workflow --entrypoint github --focus)

if [[ ${1:-} == --current ]]; then
    cwd=$(jq -r '.focused_pane_cwd // .workspace_cwd // empty' <<<"$ctx" 2>/dev/null || true)
    [[ -n $cwd && -d $cwd ]] || cwd=$HOME
    # não usar --cwd: o comando da pane é relativo à pasta do plugin; o preview faz o cd
    args+=(--env "GITHUB_MODE=current" --env "GITHUB_CWD=$cwd")
else
    url="${HERDR_PLUGIN_CLICKED_URL:-}"
    [[ -n $url ]] || { echo "sem HERDR_PLUGIN_CLICKED_URL" >&2; exit 0; }
    args+=(--env "GITHUB_URL=$url")
fi

exec "$herdr" "${args[@]}"
