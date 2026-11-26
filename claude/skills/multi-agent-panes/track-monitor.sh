#!/usr/bin/env bash
# Read-only live monitor for one Claude Code subagent track, meant to run inside a Herdr pane.
# Usage: track-monitor.sh "<title>" <agentId> [base-commit] [refresh-seconds]
# Worktree and branch come from the subagent's .meta.json, so only the agentId is needed.
# The frame repaints every second (spinner, clocks); git and the transcript are re-read every refresh-seconds.
# MONITOR_ONCE=1 renders a single frame and exits (for checking the output).
set -u
export LC_ALL=${LC_ALL:-en_US.UTF-8}

title=${1:?title}
agent=${2:?agentId}
base=${3:-}
refresh=${4:-3}
projects="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
max_commits=5 max_files=8 max_result=8 min_activity=5
once=${MONITOR_ONCE:-0}

if [ -t 1 ] || [ "$once" = 1 ]; then
  B=$(tput bold) D=$(tput dim) R=$(tput sgr0) IT=$(tput sitm 2>/dev/null)
  RED=$(tput setaf 1) GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3) BLUE=$(tput setaf 4)
  MAGENTA=$(tput setaf 5) CYAN=$(tput setaf 6) BLACK=$(tput setaf 0)
  BG_RED=$(tput setab 1) BG_GREEN=$(tput setab 2) BG_YELLOW=$(tput setab 3) BG_GREY=$(tput setab 8)
else
  B= D= R= IT= RED= GREEN= YELLOW= BLUE= MAGENTA= CYAN= BLACK= BG_RED= BG_GREEN= BG_YELLOW= BG_GREY=
fi
spinner=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
rule=$(printf '─%.0s' $(seq 1 400))
bar_on=$(printf '▰%.0s' $(seq 1 100)) bar_off=$(printf '▱%.0s' $(seq 1 100))

cleanup() { tput cnorm 2>/dev/null; printf '\n'; exit 0; }
trap cleanup INT TERM
[ "$once" = 1 ] || tput civis 2>/dev/null

mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }

# fit <text> <width>: cut to width with an ellipsis. Always measure plain text, never text with colors.
fit() {
  local s=$1 w=$2
  [ "$w" -le 0 ] && return
  if [ "${#s}" -gt "$w" ]; then printf '%s…' "${s:0:$((w - 1))}"; else printf '%s' "$s"; fi
}
pad() { local s; s=$(fit "$1" "$2"); printf '%s%*s' "$s" $(($2 - ${#s})) ''; }

# Prefixes go through variables: bash 3.2 (macOS /bin/bash) mangles "$x/" inside ${s//…/}.
shorten() {
  local s=$1 p tilde='~'
  if [ -n "${wt:-}" ]; then p="$wt/"; s=${s//$p/}; fi
  if [ -n "${repo:-}" ]; then p="$repo/"; s=${s//$p/}; fi
  p='/private/tmp/claude-*/scratchpad/'; s=${s//$p/scratch\/}
  printf '%s' "${s//$HOME/$tilde}"
}

duration() {
  local s=$1
  if [ "$s" -ge 3600 ]; then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
  elif [ "$s" -ge 60 ]; then printf '%dm%02ds' $((s / 60)) $((s % 60))
  else printf '%ds' "$s"; fi
}

section() { # section <label> [right-side plain text]
  local head="── $1 " right=${2:-}
  local fill=$((cols - ${#head} - ${#right}))
  [ "$fill" -lt 1 ] && fill=1
  out+=("${CYAN}${B}── $1 ${R}${D}${rule:0:$fill}${R}$right")
}

# One jq pass over the transcript emits tab-separated records:
#   S start_epoch last_epoch tools edits ctx_tokens model last_kind   (last_kind: handback | text | tool)
#   T done total current_task                      (only when the agent used TodoWrite)
#   A HH:MM:SS tool detail                         (tool calls; tool "»" = agent text message)
#   F final_text_with_\u001f_newlines              (handback content, else the last text message)
stats_jq='
  def epoch: (.timestamp // "" | sub("\\.[0-9]+Z$"; "Z") | try fromdateiso8601 catch null);
  def oneline: gsub("\\s+"; " ") | ltrimstr(" ");
  def detail:
    if .name == "Bash" then (.input.description // .input.command)
    elif (.name | test("^(Read|Edit|Write|MultiEdit|NotebookEdit)$")) then (.input.file_path // .input.notebook_path)
    elif .name == "Grep" then (.input.pattern + (if .input.path then "  em " + .input.path else "" end))
    elif .name == "Glob" then .input.pattern
    elif (.name | test("^(Agent|Task)$")) then .input.description
    elif .name == "TodoWrite" then "\(.input.todos | length) tarefas"
    elif .name == "Skill" then .input.skill
    else (.input.url // .input.query // .input.description // .input.prompt // ([.input[]? | strings][0]) // "")
    end // "" | tostring | oneline;
  [inputs | fromjson? | select(.type == "assistant")] as $msgs
  | ([$msgs[] | epoch | numbers]) as $times
  | ([$msgs[] | .message.content[]? | select(.type == "tool_use")]) as $tools
  | ([$msgs[] | select(.message.usage)] | last | .message.usage // {}) as $u
  | ([$tools[] | select(.name == "TodoWrite")] | last | .input.todos) as $todos
  | ($msgs | last | [.message.content[]?]) as $lastBlocks
  | ([$lastBlocks[] | select(.type == "tool_use" and .name == "SubagentHandback")] | last) as $handback
  | (if $handback then ([$handback.input[]? | strings] | first)
     else ([$msgs[] | .message.content[]? | select(.type == "text" and (.text | test("\\S"))) | .text] | last) end) as $final
  | (["S", ($times | first // 0), ($times | last // 0), ($tools | length),
       ([$tools[] | select(.name | test("^(Edit|Write|MultiEdit|NotebookEdit)$"))] | length),
       (($u.input_tokens // 0) + ($u.cache_read_input_tokens // 0) + ($u.cache_creation_input_tokens // 0)),
       ([$msgs[] | .message.model // empty] | last // "" | sub("^claude-"; "")),
       (if $handback then "handback" elif ([$lastBlocks[] | select(.type == "tool_use")] | length) == 0
          and ([$lastBlocks[] | select(.type == "text")] | length) > 0 then "text" else "tool" end)] | map(tostring) | join("\t")),
    (if $todos then ["T", ([$todos[] | select(.status == "completed")] | length), ($todos | length),
       ([$todos[] | select(.status == "in_progress")][0] | .activeForm // .content // "")]
       | map(tostring) | join("\t") else empty end),
    ($msgs[-60:][] | (epoch | if . then strflocaltime("%H:%M:%S") else "--:--:--" end) as $t
       | .message.content[]?
       | if .type == "tool_use" then ["A", $t, (if .name == "SubagentHandback" then "Entrega" else .name end), detail] | join("\t")
         elif .type == "text" and (.text | test("\\S")) then ["A", $t, "»", (.text | oneline)] | join("\t")
         else empty end),
    (if $final then "F\t" + ($final | gsub("\n"; "\u001f")) else empty end)'

load() {
  local line
  activity=() commits=() files=() todo= final= add_total=0 del_total=0
  while IFS= read -r line; do
    case $line in
      S$'\t'*) IFS=$'\t' read -r _ t_start t_last n_tools n_edits ctx model last_kind <<<"$line" ;;
      T$'\t'*) todo=${line#T$'\t'} ;;
      A$'\t'*) activity+=("${line#A$'\t'}") ;;
      F$'\t'*) final=${line#F$'\t'} ;;
    esac
  done < <(jq -R -n -r "$stats_jq" "$transcript" 2>/dev/null)

  file_age=$(( $(date +%s) - $(mtime "$transcript") ))
  stopped=$(jq -r '.stoppedByUser // false' "$meta" 2>/dev/null)

  [ -d "${wt:-/nonexistent}" ] || return
  while IFS= read -r line; do [ -n "$line" ] && commits+=("$line"); done \
    < <(git --no-optional-locks -C "$wt" log --format='%h%x09%s' "$base..HEAD" 2>/dev/null)
  # status letters joined with +/- line counts from numstat; untracked files have no numstat entry.
  while IFS= read -r line; do [ -n "$line" ] && files+=("$line"); done < <(
    awk -F'\t' 'NR == FNR { n[$3] = $1 "\t" $2; next }
                { st = substr($0, 1, 2); p = substr($0, 4); sub(/.* -> /, "", p)
                  if (p ~ /serverless\.template$/) next
                  print st "\t" p "\t" (p in n ? n[p] : "\t") }' \
      <(git --no-optional-locks -C "$wt" diff --numstat HEAD 2>/dev/null) \
      <(git --no-optional-locks -C "$wt" status --porcelain 2>/dev/null))
  for line in "${files[@]+"${files[@]}"}"; do
    IFS=$'\t' read -r _ _ a d <<<"$line"
    [[ $a =~ ^[0-9]+$ ]] && add_total=$((add_total + a))
    [[ $d =~ ^[0-9]+$ ]] && del_total=$((del_total + d))
  done
}

tool_color() {
  case $1 in
    Edit|Write|MultiEdit|NotebookEdit) printf '%s' "${YELLOW}" ;;
    Bash) printf '%s' "${CYAN}" ;;
    Read|Grep|Glob) printf '%s' "${BLUE}" ;;
    Agent|Task|Skill) printf '%s' "${MAGENTA}" ;;
    ») printf '%s' "${MAGENTA}${B}" ;;
    Entrega) printf '%s' "${GREEN}${B}" ;;
  esac
}

render() {
  # tput inside $(...) sees a pipe and falls back to 80x24, so ask the tty directly.
  local size; size=$(stty size </dev/tty 2>/dev/null)
  rows=${size% *} cols=${size#* }
  [[ $cols =~ ^[0-9]+$ && $cols -gt 0 ]] || cols=${COLUMNS:-100}
  [[ $rows =~ ^[0-9]+$ && $rows -gt 0 ]] || rows=${LINES:-40}
  # Keep the last column free: writing into it leaves some terminals in a pending-wrap state.
  cols=$((cols - 1))
  local now age state bg icon line elapsed
  now=$(date +%s)
  age=$((file_age + now - loaded_at))

  if [ "$stopped" = true ]; then state="interrompido" bg=${BG_RED} icon="■"
  elif [ "$last_kind" = handback ] || { [ "$last_kind" = text ] && [ "$age" -gt 10 ]; }; then state="terminou" bg=${BG_GREEN} icon="✓"
  elif [ "$age" -lt 90 ]; then state="trabalhando" bg=${BG_YELLOW} icon=${spinner[$((tick % ${#spinner[@]}))]}
  else state="parado" bg=${BG_GREY} icon="◌"; fi
  if [ "$state" = trabalhando ] && [ "${t_start:-0}" -gt 0 ]; then elapsed=$((now - t_start))
  else elapsed=$(( ${t_last:-0} - ${t_start:-0} )); fi

  out=()
  # Header bar colored by state: readable at a glance across stacked panes.
  local right=" ${model:-?} "
  local left=" $icon $state · $title"
  out+=("$bg${BLACK}${B}$(pad "$left" $((cols - ${#right})))$right${R}")

  local sub="⏱ $(duration "$elapsed")"
  [ "$state" = trabalhando ] || [ "$state" = parado ] && sub+=" · última atividade há $(duration "$age")"
  out+=("${D}$(fit "$sub · ${branch:-sem branch} · base ${base:0:7}" "$cols")${R}")
  out+=("$(fit "ferramentas ${n_tools:-0} · edições ${n_edits:-0} · commits ${#commits[@]} · ctx $(( ${ctx:-0} / 1000 ))k" "$cols")")

  if [ -n "$todo" ]; then
    local done total task w filled
    IFS=$'\t' read -r done total task <<<"$todo"
    w=$((cols / 3)); [ "$w" -gt 30 ] && w=30
    filled=$(( total > 0 ? done * w / total : 0 ))
    local label=" $done/$total  "
    out+=("${GREEN}${bar_on:0:$filled}${D}${bar_off:0:$((w - filled))}${R}${B}$label${R}$(fit "$task" $((cols - w - ${#label})))")
  fi

  if [ ! -d "${wt:-/nonexistent}" ]; then
    section "Worktree"; out+=("  ${D}$(fit "removida: ${wt:-desconhecida}" $((cols - 2)))${R}")
  else
    if [ "${#commits[@]}" -gt 0 ]; then
      section "Commits (${#commits[@]})"
      local i hash subj
      for ((i = ${#commits[@]} > max_commits ? ${#commits[@]} - max_commits : 0; i < ${#commits[@]}; i++)); do
        IFS=$'\t' read -r hash subj <<<"${commits[$i]}"
        out+=("  ${YELLOW}$hash${R} $(fit "$subj" $((cols - ${#hash} - 3)))")
      done
    fi
    section "Arquivos (${#files[@]})" "$([ ${#files[@]} -gt 0 ] && printf ' +%s −%s' "$add_total" "$del_total")"
    local st path a d n=0 counts color
    for line in "${files[@]+"${files[@]}"}"; do
      if [ "$n" -ge "$max_files" ]; then out+=("  ${D}… mais $(( ${#files[@]} - n ))${R}"); break; fi
      IFS=$'\t' read -r st path a d <<<"$line"
      case $st in '??'|A*|?A) color=${GREEN} counts="novo" ;; D*|?D) color=${RED} counts="removido" ;; *) color=${YELLOW} counts="+$a −$d" ;; esac
      [ "$a" = "-" ] && counts="binário"
      out+=("  $color$(pad "$st" 2)${R} $(pad "$(shorten "$path")" $((cols - ${#counts} - 7)))  ${D}$counts${R}")
      n=$((n + 1))
    done
  fi

  # Finished: the agent's last message is its hand-off, so show it before the activity log.
  local result=()
  if [ "$state" = terminou ] && [ -n "$final" ]; then
    # Leave at least min_activity rows for the activity log below.
    local keep=$((rows - ${#out[@]} - min_activity - 3))
    [ "$keep" -gt "$max_result" ] && keep=$max_result
    [ "$keep" -lt 2 ] && keep=2
    while IFS= read -r line; do result+=("$line"); done < <(shorten "${final//$'\x1f'/$'\n'}" | grep -v "^[[:space:]]*$" | fold -s -w $((cols - 4)) | head -n "$keep")
    section "Resultado"
    for line in "${result[@]+"${result[@]}"}"; do out+=("  ${IT}$line${R}"); done
  fi

  # The activity log takes whatever height is left (one row is kept free so the terminal never scrolls).
  section "Atividade"
  local room=$((rows - ${#out[@]} - 1))
  [ "$room" -lt "$min_activity" ] && room=$min_activity
  local start=$(( ${#activity[@]} > room ? ${#activity[@]} - room : 0 )) last=$(( ${#activity[@]} - 1 ))
  local t tool det label
  for ((i = start; i <= last; i++)); do
    IFS=$'\t' read -r t tool det <<<"${activity[$i]}"
    label=$(pad "$tool" 7)
    det=$(fit "$(shorten "$det")" $((cols - 20)))
    if [ "$i" -eq "$last" ]; then out+=(" ${B}▶ $t $(tool_color "$tool")$label${R} ${B}$det${R}")
    elif [ "$tool" = "»" ]; then out+=("   ${D}$t${R} $(tool_color "$tool")$label${R} ${IT}$det${R}")
    else out+=("   ${D}$t${R} $(tool_color "$tool")$label${R} ${D}$det${R}"); fi
  done
  [ "${#activity[@]}" -eq 0 ] && out+=("   ${D}sem ações ainda${R}")

  # Repaint in place (no clear) to avoid flicker; \033[K clears each line's leftovers.
  printf '\033[H'
  local k max=$(( ${#out[@]} < rows ? ${#out[@]} : rows ))
  for ((k = 0; k < max; k++)); do
    if [ "$k" -lt $((max - 1)) ]; then printf '%s\033[K\n' "${out[$k]}"; else printf '%s\033[K' "${out[$k]}"; fi
  done
  printf '\033[J'
}

t_start=0 t_last=0 n_tools=0 n_edits=0 ctx=0 model= last_kind= file_age=0 stopped=false
tick=0
# The transcript appears a moment after the Agent call returns.
transcript=
while :; do
  transcript=$(find "$projects" -path "*/subagents/agent-$agent.jsonl" -print -quit 2>/dev/null)
  [ -n "$transcript" ] && break
  printf '\033[H\033[2J%s\n%s %saguardando transcrição de agent-%s…%s' \
    "${B}$title${R}" "${spinner[$((tick % ${#spinner[@]}))]}" "${D}" "$agent" "${R}"
  [ "$once" = 1 ] && exit 1
  sleep 1; tick=$((tick + 1))
done
meta="${transcript%.jsonl}.meta.json"

# MONITOR_WORKTREE overrides the worktree for agents launched without isolation that were told
# to work in an existing worktree (e.g. a track relaunched after an interruption).
wt=${MONITOR_WORKTREE:-$(jq -r '.worktreePath // empty' "$meta" 2>/dev/null)}
branch=$(jq -r '.worktreeBranch // empty' "$meta" 2>/dev/null)
[ -n "$branch" ] || [ -z "${MONITOR_WORKTREE:-}" ] || branch=$(git -C "$wt" branch --show-current 2>/dev/null)
[ -n "$wt" ] || wt=$(head -n 5 "$transcript" | jq -r 'select(.cwd) | .cwd' 2>/dev/null | head -n 1)
repo=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
repo=${repo%/.git}
[ -n "$base" ] || base=$(git --no-optional-locks -C "$wt" rev-parse HEAD 2>/dev/null)

loaded_at=0
while :; do
  if [ $(( $(date +%s) - loaded_at )) -ge "$refresh" ]; then load; loaded_at=$(date +%s); fi
  render
  [ "$once" = 1 ] && exit 0
  sleep 1; tick=$((tick + 1))
done
