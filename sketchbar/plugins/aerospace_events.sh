#!/bin/bash

# This script monitors aerospace workspace changes and notifies sketchybar

# Prevent multiple instances
LOCKFILE="/tmp/aerospace_events.lock"
if [ -f "$LOCKFILE" ]; then
  # Check if the process is still running
  OLD_PID=$(cat "$LOCKFILE")
  if ps -p "$OLD_PID" > /dev/null 2>&1; then
    exit 0
  fi
fi
echo $$ > "$LOCKFILE"

# Cleanup on exit
trap "rm -f $LOCKFILE" EXIT

LAST_WORKSPACE=""
LAST_WINDOWS_HASH=""

while true; do
  # Get the current focused workspace
  FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null)
  
  # Get hash of all windows to detect any changes
  WINDOWS_HASH=$(aerospace list-windows --all --format '%{window-id}|%{workspace}' 2>/dev/null | sort | md5)
  
  # Update if workspace changed OR window layout changed
  if [ "$FOCUSED" != "$LAST_WORKSPACE" ] || [ "$WINDOWS_HASH" != "$LAST_WINDOWS_HASH" ]; then
    LAST_WORKSPACE="$FOCUSED"
    LAST_WINDOWS_HASH="$WINDOWS_HASH"
    
    # Call centralized update script
    /Users/keveenmenezes/.config/sketchybar/plugins/update_spaces.sh
  fi
  
  # Check every 0.3 seconds for faster response
  sleep 0.3
done
