#!/usr/bin/env bash
# Read-only live monitor for background tasks, meant to run inside a Herdr pane. Repaints every second.
# Usage:
#   bg-monitor.sh "<label>" <output-file> [start-epoch]   one task
#   bg-monitor.sh --dashboard <bg-tasks.tsv | state-dir>  one row per task in the registry
#   bg-monitor.sh --pane <pane-id> <state-dir>            pool mode (what bg-pool.sh starts): the pane follows its
#       role in panes.tsv (task or dashboard) and the task assigned to it in bg-tasks.tsv, and once its task has
#       finished and the hold time has passed it claims the oldest active task that is only on the dashboard.
# The output file is only ever tailed. Pool mode also writes the claim to the registry and renames its own pane.
# MONITOR_ONCE=1 renders a single frame and exits (for checking the output).
set -u
export LC_ALL=${LC_ALL:-en_US.UTF-8}
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=bg-lib.sh
. "$here/bg-lib.sh"

once=${MONITOR_ONCE:-0}
if [ -t 1 ] || [ "$once" = 1 ]; then
  B=$(tput bold) D=$(tput dim) R=$(tput sgr0)
  RED=$(tput setaf 1) GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3) CYAN=$(tput setaf 6) BLACK=$(tput setaf 0)
  GREY=$(tput setaf 8)
  BG_RED=$(tput setab 1) BG_GREEN=$(tput setab 2) BG_YELLOW=$(tput setab 3) BG_GREY=$(tput setab 8)
else
  B= D= R= RED= GREEN= YELLOW= CYAN= BLACK= GREY= BG_RED= BG_GREEN= BG_YELLOW= BG_GREY=
fi
spinner=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
rule=$(printf '─%.0s' $(seq 1 400))
re_err='(error|failed|failure|exception|fatal|panic|denied)'
re_warn='warn'
# "0 Error(s)", "Failed: 0" and the like are summaries of a clean run, not problems.
re_zero='(^|[^0-9])0 (error|warning|failed)|(error|warning|failed)(\(s\))?:?[[:space:]]+0([^0-9]|$)'
shopt -s nocasematch

cleanup() { tput cnorm 2>/dev/null; printf '\n'; exit 0; }
trap cleanup INT TERM
[ "$once" = 1 ] || tput civis 2>/dev/null

# fit <text> <width>: cut to width with an ellipsis. Always measure plain text, never text with colors.
fit() {
  local s=$1 w=$2
  [ "$w" -le 0 ] && return
  if [ "${#s}" -gt "$w" ]; then printf '%s…' "${s:0:$((w - 1))}"; else printf '%s' "$s"; fi
}
pad() { local s; s=$(fit "$1" "$2"); printf '%s%*s' "$s" $(($2 - ${#s})) ''; }
# Session temp paths (/private/tmp/claude-<uid>/<project>/<session>/...) keep only the part after the session dir.
shorten() {
  local s=$1 tilde='~'
  [[ $s =~ ^/private/tmp/claude-[0-9]+/[^/]+/[^/]+/(.*)$ ]] && s=${BASH_REMATCH[1]}
  printf '%s' "${s//$HOME/$tilde}"
}

highlight() {
  if [[ $1 =~ $re_zero ]]; then printf '%s' "$1"
  elif [[ $1 =~ $re_err ]]; then printf '%s' "${RED}$1${R}"
  elif [[ $1 =~ $re_warn ]]; then printf '%s' "${YELLOW}$1${R}"
  else printf '%s' "$1"; fi
}

measure() {
  # tput inside $(...) sees a pipe and falls back to 80x24, so ask the tty directly.
  local size; size=$( { stty size </dev/tty; } 2>/dev/null )
  rows=${size% *} cols=${size#* }
  [[ $cols =~ ^[0-9]+$ && $cols -gt 0 ]] || cols=${COLUMNS:-100}
  [[ $rows =~ ^[0-9]+$ && $rows -gt 0 ]] || rows=${LINES:-30}
  # Keep the last column free: writing into it leaves some terminals in a pending-wrap state.
  cols=$((cols - 1))
}

# Repaint in place (no clear) to avoid flicker; \033[K clears each line's leftovers.
paint() {
  local k max=$(( ${#out[@]} < rows ? ${#out[@]} : rows ))
  printf '\033[H'
  for ((k = 0; k < max; k++)); do
    if [ "$k" -lt $((max - 1)) ]; then printf '%s\033[K\n' "${out[$k]}"; else printf '%s\033[K' "${out[$k]}"; fi
  done
  printf '\033[J'
}

bar() { # bar <bg> <left> <right>
  out+=("$1${BLACK}${B}$(pad "$2" $((cols - ${#3})))$3${R}")
}

icon_for() { # sets icon/fg/bg/word for the current $st
  case $st in
    run) icon=${spinner[$((tick % ${#spinner[@]}))]} fg=$YELLOW bg=$BG_YELLOW word="rodando" ;;
    wait) icon=${spinner[$((tick % ${#spinner[@]}))]} fg=$GREY bg=$BG_GREY word="aguardando output" ;;
    stale) icon="◌" fg=$GREY bg=$BG_GREY word="parado" ;;
    ok) icon="✓" fg=$GREEN bg=$BG_GREEN word="concluído" ;;
    fail) icon="✗" fg=$RED bg=$BG_RED word="falhou · código $code" ;;
  esac
}

elapsed_of() { # elapsed_of <file> <start>: run time, frozen once the task finished
  local start=$2
  [ -n "$start" ] && [ "$start" != 0 ] || start=$( [ -e "$1" ] && btime "$1" || date +%s )
  if [ "$st" = ok ] || [ "$st" = fail ]; then elapsed=$(( $(mtime "$1") - start ))
  else elapsed=$(( $(date +%s) - start )); fi
}

render_task() { # render_task <label> <file> <start> [hold-note]
  local label=$1 file=$2 line n=0
  task_state "$file"
  icon_for; elapsed_of "$file" "$3"
  out=()
  bar "$bg" " $icon $word · $label" " ⏱ $(duration "$elapsed") "

  local sub
  case $st in
    wait) sub="arquivo ainda não existe" ;;
    ok|fail) sub="terminou há $(duration "$age")" ;;
    *) sub="última saída há $(duration "$age")" ;;
  esac
  [ -e "$file" ] && sub+=" · $(human_size "$(fsize "$file")")"
  [ -n "${4:-}" ] && sub+=" · $4"
  out+=("${D}$(fit "$sub · $(shorten "$file")" "$cols")${R}")
  out+=("${D}${rule:0:$cols}${R}")

  local room=$((rows - ${#out[@]})) lines=()
  if [ -e "$file" ] && [ "$room" -gt 0 ]; then
    while IFS= read -r line; do
      [[ $line =~ ^[[:space:]]*$ ]] || lines+=("$line")
    done < <(tail -n $((room * 2 + 20)) "$file" | clean_output)
  fi
  local i start=$(( ${#lines[@]} > room ? ${#lines[@]} - room : 0 ))
  for ((i = start; i < ${#lines[@]}; i++)); do out+=("$(highlight "$(fit "${lines[$i]}" "$cols")")"); done
  [ "${#lines[@]}" -eq 0 ] && out+=("${D}sem saída ainda${R}")
}

last_line() { # last non-blank cleaned line of a file
  [ -e "$1" ] || return
  tail -n 30 "$1" | clean_output | awk 'NF { l = $0 } END { sub(/^[ \t]+/, "", l); print l }'
}

render_dashboard() { # render_dashboard <bg-tasks.tsv>
  local reg=$1 id label file start pane rec active=() fin=() n_run=0 n_ok=0 n_fail=0
  out=()
  # Records carry state, sort key and the already-measured fields, so each file is inspected once per frame.
  while IFS=$'\t' read -r id label file start pane; do
    [ -n "$id" ] || continue
    task_state "$file"; elapsed_of "$file" "$start"
    # Tabs are IFS whitespace, so an empty field would collapse: keep every field non-empty.
    rec="$st"$'\t'"${code:--}"$'\t'"$label"$'\t'"$elapsed"$'\t'"$pane"$'\t'"$file"
    if is_active; then active+=("$start"$'\t'"$rec"); n_run=$((n_run + 1))
    else fin+=("$age"$'\t'"$rec"); [ "$st" = ok ] && n_ok=$((n_ok + 1)) || n_fail=$((n_fail + 1)); fi
  done <"$reg"

  local head=" ▤ background · $n_run rodando · $n_ok ✓ · $n_fail ✗" hbg=$BG_GREEN
  if [ "$n_run" -gt 0 ]; then hbg=$BG_YELLOW; elif [ "$n_fail" -gt 0 ]; then hbg=$BG_RED; fi
  [ $((n_run + n_ok + n_fail)) -eq 0 ] && hbg=$BG_GREY
  bar "$hbg" "$head" " ▣ em pane · · só aqui "

  local lw=$((cols / 3)); [ "$lw" -gt 28 ] && lw=28; [ "$lw" -lt 10 ] && lw=10
  local sorted=() k
  # Active tasks oldest first, then finished ones most recent first.
  [ "${#active[@]}" -gt 0 ] && while IFS= read -r k; do sorted+=("$k"); done < <(printf '%s\n' "${active[@]}" | sort -n -t $'\t' -k1,1)
  [ "${#fin[@]}" -gt 0 ] && while IFS= read -r k; do sorted+=("$k"); done < <(printf '%s\n' "${fin[@]}" | sort -n -t $'\t' -k1,1)

  local room=$((rows - ${#out[@]})) shown=0 total=${#sorted[@]} key el place last tail_w
  for k in "${sorted[@]+"${sorted[@]}"}"; do
    if [ "$shown" -ge $((room - 1)) ] && [ "$total" -gt "$room" ]; then
      out+=("${D}  … mais $((total - shown)) tarefas${R}"); break
    fi
    IFS=$'\t' read -r key st code label el pane file <<<"$k"
    icon_for
    if [ "$pane" = "-" ]; then place="·"; else place="▣"; fi
    last=$(last_line "$file")
    [ "$st" = fail ] && last="código $code · $last"
    [ "$st" = wait ] && last="aguardando output"
    tail_w=$((cols - lw - 15))
    local lstyle=$B; is_active || lstyle=
    out+=(" $fg$icon${R} $lstyle$(pad "$label" "$lw")${R} ${D}$(pad "$(duration "$el")" 7)${R} $place  $(highlight "$(fit "$last" "$tail_w")")")
    shown=$((shown + 1))
  done
  [ "$total" -eq 0 ] && out+=("${D}  nenhuma tarefa registrada${R}")
}

render_idle() { # render_idle <message>
  out=()
  bar "$BG_GREY" " ◌ $1" " "
}

rename_pane() { # only when the name changes: herdr renames are not free
  [ "$1" = "${last_name:-}" ] && return
  herdr pane rename "$pane_id" "$1" >/dev/null 2>&1 && last_name=$1
}

# Pool mode: once this pane's task is releasable, take the oldest active task that has no pane.
recycle() { # recycle <my-task-id>
  releasable || return
  local id label file start pane cand=
  while IFS=$'\t' read -r id label file start pane; do
    task_state "$file"
    if is_active; then cand=$id; break; fi
  done < <(awk -F'\t' '$5 == "-"' "$dir/bg-tasks.tsv" | sort -n -t $'\t' -k4,4)
  [ -n "$cand" ] || return
  lock "$dir"
  # Re-check under the lock: bg-pool.sh or another pane may have moved things meanwhile.
  if awk -F'\t' -v c="$cand" -v me="$1" -v p="$pane_id" \
       '$1 == c && $5 == "-" { a = 1 } $1 == me && $5 == p { b = 1 } END { exit !(a && b) }' "$dir/bg-tasks.tsv"; then
    set_task_pane "$dir" "$1" "-"
    set_task_pane "$dir" "$cand" "$pane_id"
  fi
  unlock "$dir"
}

tick=0
case ${1:-} in
  --dashboard)
    reg=${2:?bg-tasks.tsv or state dir}
    [ -d "$reg" ] && reg="$reg/bg-tasks.tsv"
    while :; do
      measure
      if [ -e "$reg" ]; then render_dashboard "$reg"; else render_idle "aguardando registro $(shorten "$reg")"; fi
      paint
      [ "$once" = 1 ] && exit 0
      sleep 1; tick=$((tick + 1))
    done ;;
  --pane)
    pane_id=${2:?pane-id} dir=${3:?state dir}
    while :; do
      measure
      role=$(awk -F'\t' -v p="$pane_id" '$1 == p { print $2 }' "$dir/panes.tsv" 2>/dev/null)
      case $role in
        dashboard)
          render_dashboard "$dir/bg-tasks.tsv"
          rename_pane "background · painel" ;;
        task)
          row=$(awk -F'\t' -v p="$pane_id" '$5 == p' "$dir/bg-tasks.tsv" 2>/dev/null | tail -n 1)
          if [ -n "$row" ]; then
            IFS=$'\t' read -r t_id t_label t_file t_start _ <<<"$row"
            # render_task leaves st/age of this task behind, which recycle reads.
            render_task "$t_label" "$t_file" "$t_start"
            rename_pane "$t_label"
            recycle "$t_id"
          else
            render_idle "pane livre · aguardando próxima tarefa"
            rename_pane "background · livre"
          fi ;;
        *) render_idle "pane fora do pool (bg-pool.sh close?)" ;;
      esac
      paint
      [ "$once" = 1 ] && exit 0
      sleep 1; tick=$((tick + 1))
    done ;;
  *)
    label=${1:?label} file=${2:?output file} start=${3:-0}
    while :; do
      measure
      render_task "$label" "$file" "$start"
      paint
      [ "$once" = 1 ] && exit 0
      sleep 1; tick=$((tick + 1))
    done ;;
esac
