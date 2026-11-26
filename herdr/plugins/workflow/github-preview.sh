#!/usr/bin/env bash
# Popup de PR/issue: mostra o item e deixa navegar por teclas.
# Usa a conta ativa do gh; se ela não enxerga o repositório, tenta as outras contas logadas.
set -uo pipefail
export PATH="/opt/homebrew/bin:$PATH"

url="${GITHUB_URL:-}"
mode="${GITHUB_MODE:-url}"

pause() { printf '\n\033[2m[enter] fechar\033[0m'; read -r _ || true; }

if [[ $mode == current ]]; then
    cd "${GITHUB_CWD:-$HOME}" 2>/dev/null || cd "$HOME"
    repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
    number=$(gh pr view --json number -q .number 2>/dev/null || true)
    if [[ -z $repo || -z $number ]]; then
        echo "nenhum PR aberto para o branch de $(pwd)"
        pause
        exit 0
    fi
    kind=pull
elif [[ $url =~ ^https://github\.com/([^/]+)/([^/]+)/(issues|pull)/([0-9]+) ]]; then
    repo="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    kind="${BASH_REMATCH[3]}"
    number="${BASH_REMATCH[4]}"
else
    echo "link não suportado: $url"
    pause
    exit 0
fi

# escolhe a conta que enxerga o repositório
if ! gh api "repos/$repo" --silent >/dev/null 2>&1; then
    while read -r login; do
        token=$(gh auth token --user "$login" 2>/dev/null) || continue
        if GH_TOKEN=$token gh api "repos/$repo" --silent >/dev/null 2>&1; then
            export GH_TOKEN=$token
            break
        fi
    done < <(gh auth status --json hosts --jq '.hosts["github.com"][] | select(.active | not) | .login' 2>/dev/null)
fi

show() {
    clear
    case "$1" in
    view)
        if [[ $kind == pull ]]; then
            gh pr view "$number" --repo "$repo" --comments
        else
            gh issue view "$number" --repo "$repo" --comments
        fi
        ;;
    checks) gh pr checks "$number" --repo "$repo" ;;
    diff) gh pr diff "$number" --repo "$repo" --color always | delta --paging=always ;;
    esac
}

view=view
while :; do
    show "$view" 2>&1 | less -R -F -X
    if [[ $kind == pull ]]; then
        printf '\n\033[38;2;41;184;219m%s #%s\033[0m  [v] PR  [c] checks  [d] diff  [w] navegador  [q] fechar ' "$repo" "$number"
    else
        printf '\n\033[38;2;41;184;219m%s #%s\033[0m  [v] issue  [w] navegador  [q] fechar ' "$repo" "$number"
    fi
    read -rsn1 key || exit 0
    case "$key" in
    v) view=view ;;
    c) [[ $kind == pull ]] && view=checks ;;
    d) [[ $kind == pull ]] && view=diff ;;
    w) open "https://github.com/$repo/$kind/$number" ;;
    q | $'\e' | '') exit 0 ;;
    esac
done
