# Shared helpers for bg-monitor.sh and bg-pool.sh (sourced, never run). Keep it bash 3.2 compatible (macOS /bin/bash).
#
# State lives in one directory per session (<scratchpad>/bg-panes):
#   bg-tasks.tsv  id <TAB> label <TAB> output-file <TAB> start-epoch <TAB> pane-id | -   (- = only on the dashboard)
#   panes.tsv     pane-id <TAB> task | dashboard                          (only panes this skill created)
# Writers take the mkdir lock and replace files with mv, so readers always see a whole file.

max_panes=4      # pool size shared with multi-agent-panes
stale_after=90   # seconds without new output before a running task shows as stalled
done_hold=60     # seconds a ✓ task keeps its pane before the pane can be recycled
fail_hold=300    # same for ✗, longer so the error can be read

mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }
btime() { stat -f %B "$1" 2>/dev/null || stat -c %W "$1" 2>/dev/null || mtime "$1"; }
fsize() { stat -f %z "$1" 2>/dev/null || stat -c %s "$1" 2>/dev/null || echo 0; }

duration() {
  local s=$1
  [ "$s" -lt 0 ] && s=0
  if [ "$s" -ge 3600 ]; then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
  elif [ "$s" -ge 60 ]; then printf '%dm%02ds' $((s / 60)) $((s % 60))
  else printf '%ds' "$s"; fi
}

human_size() {
  local b=$1
  if [ "$b" -ge 1048576 ]; then printf '%d.%d MB' $((b / 1048576)) $((b % 1048576 * 10 / 1048576))
  elif [ "$b" -ge 1024 ]; then printf '%d KB' $((b / 1024))
  else printf '%d B' "$b"; fi
}

# task_state <file>: sets st (wait | run | stale | ok | fail), code (exit code once finished) and age
# (seconds since the last write; for a finished task that is how long ago it finished).
# The command must end with `; echo "__EXIT__ $?"`; output without a trailing newline glues the marker
# to the last line, so it is matched at the end of any line. Claude Code's own background output files
# also end with "[exited with code N]", which counts as a marker too.
task_state() {
  local f=$1
  code=
  if [ ! -e "$f" ]; then st=wait age=0; return; fi
  age=$(( $(date +%s) - $(mtime "$f") ))
  # __EXIT__ wins: the harness line reports the exit code of that final echo, which is always 0.
  local tail_txt; tail_txt=$(tail -c 400 "$f" | LC_ALL=C tr '\r' '\n')
  code=$(LC_ALL=C sed -n -E 's/.*__EXIT__ ([0-9]+)[[:space:]]*$/\1/p' <<<"$tail_txt" | tail -n 1)
  [ -n "$code" ] || code=$(LC_ALL=C sed -n -E 's/^\[exited with code ([0-9]+)\][[:space:]]*$/\1/p' <<<"$tail_txt" | tail -n 1)
  if [ -n "$code" ]; then
    if [ "$code" = 0 ]; then st=ok; else st=fail; fi
  elif [ "$age" -ge "$stale_after" ]; then st=stale
  else st=run; fi
}

# A finished task frees its pane after the hold time.
releasable() { { [ "$st" = ok ] && [ "$age" -ge "$done_hold" ]; } || { [ "$st" = fail ] && [ "$age" -ge "$fail_hold" ]; }; }
is_active() { [ "$st" = run ] || [ "$st" = stale ] || [ "$st" = wait ]; }

# clean_output: stdin → printable lines. Drops ANSI sequences, keeps only what follows the last \r
# (progress bars redraw with \r), expands tabs and hides the __EXIT__ marker.
clean_output() {
  LC_ALL=C sed -E $'s/\x1b\\[[0-9;?]*[ -/]*[@-~]//g; s/\x1b\\][^\x07]*\x07//g; s/\x1b[()][0-9A-Za-z]//g' \
    | awk '{ n = split($0, a, "\r"); s = a[n]; if (s == "" && n > 1) s = a[n - 1]; sub(/__EXIT__ [0-9]+[ \t]*$/, "", s)
           if (s !~ /^\[exited with code [0-9]+\][ \t]*$/) print s }' \
    | expand -t 4
}

lock() {
  local i=0
  until mkdir "$1/.lock" 2>/dev/null; do
    i=$((i + 1))
    # A lock older than 10s belongs to a writer that died mid-update.
    if [ "$i" -ge 50 ] && [ $(( $(date +%s) - $(mtime "$1/.lock") )) -gt 10 ]; then rmdir "$1/.lock" 2>/dev/null; fi
    sleep 0.1
  done
}
unlock() { rmdir "$1/.lock" 2>/dev/null; }

# set_task_pane <dir> <task-id> <pane-id|->: caller holds the lock.
set_task_pane() {
  awk -F'\t' -v OFS='\t' -v id="$2" -v p="$3" '$1 == id { $5 = p } { print }' "$1/bg-tasks.tsv" >"$1/bg-tasks.tsv.tmp" \
    && mv "$1/bg-tasks.tsv.tmp" "$1/bg-tasks.tsv"
}

# set_pane_role <dir> <pane-id> <task|dashboard|->: "-" removes the pane. Caller holds the lock.
set_pane_role() {
  touch "$1/panes.tsv"
  awk -F'\t' -v OFS='\t' -v p="$2" -v r="$3" '$1 == p { if (r != "-") print p, r; found = 1; next } { print }
    END { if (!found && r != "-") print p, r }' "$1/panes.tsv" >"$1/panes.tsv.tmp" && mv "$1/panes.tsv.tmp" "$1/panes.tsv"
}
