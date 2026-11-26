#!/usr/bin/env bash
# Receita padrão de uma aba de repositório (usada quando não existe ~/.config/task/layouts/<repo>.sh).
#
# Recebe no ambiente: TASK_ID, TASK_DIR, REPO (nome do repositório principal), REPO_DIR (worktree),
# TAB_ID e ROOT_PANE, e as funções de task/lib.sh (pane_split, pane_type, pane_run, pane_label…).
#
# Layout: shell do repositório à esquerda; à direita, uma pane "run" com o comando do projeto
# DIGITADO, sem executar — várias tarefas abertas não brigam por porta. Enter quando quiser.

run_cmd=""
if [[ -f $REPO_DIR/package.json ]]; then
    for s in dev start serve; do
        if jq -e --arg s "$s" '.scripts[$s]' "$REPO_DIR/package.json" >/dev/null 2>&1; then
            run_cmd="npm run $s"
            break
        fi
    done
elif compgen -G "$REPO_DIR/*.sln" >/dev/null || compgen -G "$REPO_DIR/*.slnx" >/dev/null; then
    run_cmd="dotnet build"
elif [[ -f $REPO_DIR/go.mod ]]; then
    run_cmd="go test ./..."
elif [[ -f $REPO_DIR/pyproject.toml ]]; then
    run_cmd="uv run pytest"
fi
if [[ -z $run_cmd ]] && { [[ -f $REPO_DIR/docker-compose.yml ]] || [[ -f $REPO_DIR/compose.yml ]]; }; then
    run_cmd="docker compose up -d && docker compose logs -f"
fi

pane_label "$ROOT_PANE" "$REPO"
if [[ -n $run_cmd ]]; then
    run=$(pane_split "$ROOT_PANE" right "$REPO_DIR" 0.42)
    pane_label "$run" "run"
    pane_type "$run" "$run_cmd"
fi
