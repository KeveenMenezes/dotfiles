#!/usr/bin/env bash
# Mantém a skill oficial do herdr no Claude Code igual à da versão instalada.
# Roda no startup do servidor (inclusive depois de `herdr update`) e pela action sync-skill.
set -euo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
dest="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/herdr/SKILL.md"

mkdir -p "$(dirname "$dest")"
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
"$herdr" --skill >"$tmp"

if [[ -s $tmp ]] && ! cmp -s "$tmp" "$dest"; then
    cp "$tmp" "$dest"
    echo "skill do herdr atualizada em $dest ($("$herdr" --version))"
else
    echo "skill do herdr já está atualizada"
fi
