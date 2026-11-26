#!/usr/bin/env bash
# Pane "github" do plugin: delega ao painel bin/pr-view.
#   GITHUB_URL=<link>                    Ctrl+clique num link de PR/issue
#   GITHUB_MODE=current GITHUB_CWD=<dir> PR do branch da pane focada (prefix+ctrl+r)
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
if [[ ${GITHUB_MODE:-} == current ]]; then
    exec pr-view --current "${GITHUB_CWD:-$HOME}"
fi
exec pr-view "${GITHUB_URL:-}"
