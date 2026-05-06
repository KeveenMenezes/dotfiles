#!/usr/bin/env bash

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

aerospace workspace infra

open -na Ghostty --args -e nu -c "lazydocker"

sleep 1.5

open -na Ghostty --args -e nu -c "cd ~/Documents/projects/work/database-cicd; nvim +'lua toggle_dbee()'"
