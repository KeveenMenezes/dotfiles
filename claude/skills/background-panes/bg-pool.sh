#!/usr/bin/env bash
# Pool manager for background-task panes in Herdr. Decides placement so the controller only makes one call per task.
# Usage:
#   bg-pool.sh add <state-dir> "<label>" <output-file>   register a task and give it a pane (or the dashboard)
#   bg-pool.sh status <state-dir>                        one line per task, plus the pool occupancy
#   bg-pool.sh count                                     panes in this tab besides the user's (the shared pool)
#   bg-pool.sh close <state-dir>                         stop and close the panes this skill opened
# The pool is every pane in the tab of $HERDR_PANE_ID except that pane, so panes opened by multi-agent-panes count
# toward the same limit without any coordination. Only panes listed in panes.tsv are ever reused or closed.
set -u
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=bg-lib.sh
. "$here/bg-lib.sh"

me=${HERDR_PANE_ID:?not inside Herdr}

# pool_panes: "pane-id<TAB>x<TAB>height" for every pane of this tab except the user's; also sets my_x.
pool_panes() {
  local json
  json=$(herdr pane layout --pane "$me") || return 1
  my_x=$(jq -r --arg me "$me" '.result.layout.panes[] | select(.pane_id == $me) | .rect.x' <<<"$json")
  pool=$(jq -r --arg me "$me" '.result.layout.panes[] | select(.pane_id != $me) | [.pane_id, .rect.x, .rect.height] | @tsv' <<<"$json")
  pool_n=$(printf '%s' "$pool" | grep -c . || true)
}

# Forget panes the user closed by hand; their tasks fall back to the dashboard.
prune() {
  local p
  while IFS=$'\t' read -r p _; do
    [ -n "$p" ] || continue
    if ! printf '%s\n' "$pool" | cut -f1 | grep -qx "$p"; then
      set_pane_role "$dir" "$p" "-"
      awk -F'\t' -v p="$p" '$5 == p { print $1 }' "$dir/bg-tasks.tsv" | while read -r id; do set_task_pane "$dir" "$id" "-"; done
    fi
  done <"$dir/panes.tsv"
}

# First pane: split the user's pane to the right. Next ones: halve the tallest pane of the right column, which keeps
# the stack close to even without resizing panes the user may have arranged.
create_pane() {
  local target dir_flag=down ratio=0.5 p
  target=$(printf '%s\n' "$pool" | awk -F'\t' -v x="$my_x" 'NF && $2 > x' | sort -t $'\t' -k3,3nr | head -n 1 | cut -f1)
  if [ -z "$target" ]; then target=$me dir_flag=right; fi
  p=$(herdr pane split --pane "$target" --direction "$dir_flag" --ratio "$ratio" --no-focus --cwd "$PWD" \
      | jq -r '.result.pane.pane_id // empty')
  [ -n "$p" ] || return 1
  set_pane_role "$dir" "$p" task
  printf '%s' "$p"
}

start_monitor() {
  # herdr pane run types into the pane's shell (maybe nushell), so pass only a plain command with quoted args.
  herdr pane run "$1" "bash '$here/bg-monitor.sh' --pane '$1' '$dir'" >/dev/null
}

cmd_add() {
  local label=${1:?label} file=${2:?output file} id p row t_file target= dash=
  lock "$dir"
  trap 'unlock "$dir"' EXIT
  id=$(awk -F'\t' '$1 + 0 > m { m = $1 + 0 } END { print m + 1 }' "$dir/bg-tasks.tsv")
  # The task started when its output file appeared, which is usually a few seconds before this call.
  local start; start=$(date +%s)
  [ -e "$file" ] && [ "$(btime "$file")" -lt "$start" ] && start=$(btime "$file")
  printf '%s\t%s\t%s\t%s\t-\n' "$id" "${label//$'\t'/ }" "$file" "$start" >>"$dir/bg-tasks.tsv"
  pool_panes || { echo "erro: herdr pane layout falhou"; return 1; }
  prune

  # 1. Reuse one of our task panes that is free or whose task finished and has passed its hold time.
  while IFS=$'\t' read -r p _; do
    row=$(awk -F'\t' -v p="$p" '$5 == p' "$dir/bg-tasks.tsv" | tail -n 1)
    if [ -z "$row" ]; then target=$p; break; fi
    t_file=$(cut -f3 <<<"$row")
    task_state "$t_file"
    if releasable; then set_task_pane "$dir" "$(cut -f1 <<<"$row")" "-"; target=$p; break; fi
  done < <(awk -F'\t' '$2 == "task"' "$dir/panes.tsv")

  # 2. Open a new pane while the shared pool has room.
  if [ -z "$target" ] && [ "$pool_n" -lt "$max_panes" ]; then
    target=$(create_pane) && start_monitor "$target"
  fi

  if [ -n "$target" ]; then
    set_task_pane "$dir" "$id" "$target"
    echo "pane $target"
    return
  fi

  # 3. Pool full: the task lives on the dashboard; the first time, our last task pane becomes the dashboard
  #    (its monitor follows the role change on its own) and its task joins the dashboard too.
  dash=$(awk -F'\t' '$2 == "dashboard" { print $1 }' "$dir/panes.tsv" | head -n 1)
  if [ -z "$dash" ]; then
    dash=$(awk -F'\t' '$2 == "task" { p = $1 } END { print p }' "$dir/panes.tsv")
    if [ -n "$dash" ]; then
      awk -F'\t' -v p="$dash" '$5 == p { print $1 }' "$dir/bg-tasks.tsv" | while read -r t; do set_task_pane "$dir" "$t" "-"; done
      set_pane_role "$dir" "$dash" dashboard
    fi
  fi
  if [ -n "$dash" ]; then echo "dashboard $dash"
  else echo "sem pane: o pool de $max_panes está cheio com panes de outra skill (tarefa registrada, sem monitor)"; fi
}

cmd_status() {
  local id label file start pane el n_active=0
  while IFS=$'\t' read -r id label file start pane; do
    [ -n "$id" ] || continue
    task_state "$file"
    if [ "$st" = ok ] || [ "$st" = fail ]; then el=$(( $(mtime "$file") - start )); else el=$(( $(date +%s) - start )); fi
    is_active && n_active=$((n_active + 1))
    printf '%-3s %-8s %-8s %-8s %s\n' "$id" "$st${code:+($code)}" "$(duration "$el")" "$pane" "$label"
  done <"$dir/bg-tasks.tsv"
  pool_panes && echo "pool: $pool_n/$max_panes panes na aba ($(grep -c . "$dir/panes.tsv" || true) desta skill) · ativas: $n_active"
}

cmd_close() {
  local p
  lock "$dir"
  trap 'unlock "$dir"' EXIT
  while IFS=$'\t' read -r p _; do
    [ -n "$p" ] || continue
    herdr pane send-keys "$p" ctrl+c >/dev/null 2>&1
    herdr pane close "$p" >/dev/null 2>&1 && echo "fechada $p"
  done <"$dir/panes.tsv"
  : >"$dir/panes.tsv"
  awk -F'\t' -v OFS='\t' '{ $5 = "-"; print }' "$dir/bg-tasks.tsv" >"$dir/bg-tasks.tsv.tmp" && mv "$dir/bg-tasks.tsv.tmp" "$dir/bg-tasks.tsv"
}

case ${1:-} in
  count) pool_panes && echo "$pool_n" ;;
  add|status|close)
    cmd=$1 dir=${2:?state dir}
    shift 2
    mkdir -p "$dir" && touch "$dir/bg-tasks.tsv" "$dir/panes.tsv"
    "cmd_$cmd" "$@" ;;
  *) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
