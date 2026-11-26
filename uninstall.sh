#!/bin/bash

# Dotfiles Uninstallation Script
# This script removes symbolic links and restores backups if available

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}🗑️  Uninstalling dotfiles...${NC}"

# Function to remove symlink and restore backup
remove_symlink() {
    local target="$1"
    local name="$2"
    
    if [ -L "$target" ]; then
        echo -e "${YELLOW}🔗 Removing symlink: $target${NC}"
        rm "$target"
        
        # Look for most recent backup
        local backup=$(ls -t "${target}.backup."* 2>/dev/null | head -n1)
        if [ -n "$backup" ]; then
            echo -e "${GREEN}📦 Restoring backup: $backup -> $target${NC}"
            mv "$backup" "$target"
        fi
    else
        echo -e "${YELLOW}⚠️  No symlink found for $name at $target${NC}"
    fi
}

# Remove SketchyBar configuration
echo -e "\n${RED}🎨 Removing SketchyBar configuration...${NC}"
SKETCHYBAR_CONFIG_DIR="$HOME/.config/sketchybar"
if [ -L "$SKETCHYBAR_CONFIG_DIR" ]; then
    rm "$SKETCHYBAR_CONFIG_DIR"
    # Look for backup
    backup=$(ls -td "${SKETCHYBAR_CONFIG_DIR}.backup."* 2>/dev/null | head -n1)
    if [ -n "$backup" ]; then
        echo -e "${GREEN}📦 Restoring SketchyBar backup${NC}"
        mv "$backup" "$SKETCHYBAR_CONFIG_DIR"
    fi
fi

# Remove AeroSpace configuration
echo -e "\n${RED}✈️ Removing AeroSpace configuration...${NC}"
remove_symlink "$HOME/.config/aerospace/aerospace.toml" "AeroSpace"

# Remove VS Code configuration
echo -e "\n${RED}📝 Removing VS Code configuration...${NC}"
VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"
remove_symlink "$VSCODE_CONFIG_DIR/settings.json" "VS Code settings"
remove_symlink "$VSCODE_CONFIG_DIR/keybindings.json" "VS Code keybindings"

# Remove Ghostty configuration
echo -e "\n${RED}👻 Removing Ghostty configuration...${NC}"
GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
remove_symlink "$GHOSTTY_CONFIG_DIR/config" "Ghostty config"
remove_symlink "$GHOSTTY_CONFIG_DIR/themes/prom-wiki" "Ghostty prom-wiki theme"
remove_symlink "$GHOSTTY_CONFIG_DIR/themes/prom-lilas" "Ghostty prom-lilas theme"

# Remove herdr configuration
echo -e "\n${RED}🐑 Removing herdr configuration...${NC}"
HERDR_CONFIG_DIR="$HOME/.config/herdr"
remove_symlink "$HERDR_CONFIG_DIR/config.toml" "herdr config"
remove_symlink "$HERDR_CONFIG_DIR/scripts" "herdr scripts"
command -v herdr >/dev/null 2>&1 && herdr plugin unlink keveen.workflow >/dev/null 2>&1 || true

# Remove Claude Code skills linked from this repo (a skill oficial do herdr não é link e fica)
echo -e "\n${RED}🤖 Removing Claude Code skills...${NC}"
for skill in "$(dirname "$0")"/claude/skills/*/; do
    remove_symlink "$HOME/.claude/skills/$(basename "$skill")" "Claude skill $(basename "$skill")"
done

# Remove Nushell configuration
echo -e "\n${RED}🐚 Removing Nushell configuration...${NC}"
NU_CONFIG_DIR="$HOME/Library/Application Support/nushell"
remove_symlink "$NU_CONFIG_DIR/config.nu" "Nushell config"
remove_symlink "$NU_CONFIG_DIR/env.nu" "Nushell env"
remove_symlink "$NU_CONFIG_DIR/autoload/direnv.nu" "Nushell direnv hook"
remove_symlink "$NU_CONFIG_DIR/autoload/_fzf_integration.nu" "Nushell fzf integration"

# Remove Starship, atuin, lazygit, git, Colima configuration
echo -e "\n${RED}🚀 Removing Starship, atuin, lazygit, git and Colima configuration...${NC}"
remove_symlink "$HOME/.config/starship.toml" "Starship"
remove_symlink "$HOME/.config/atuin/config.toml" "atuin"
remove_symlink "$HOME/Library/Application Support/lazygit/config.yml" "lazygit"
remove_symlink "$HOME/.local/bin/tema" "tema command"
remove_symlink "$HOME/.local/bin/lazysql-kc" "lazysql-kc command"
remove_symlink "$HOME/.local/bin/task" "task command"
remove_symlink "$HOME/.local/bin/pr-view" "pr-view command"
remove_symlink "$HOME/.local/bin/keymap-view" "keymap-view command"
remove_symlink "$HOME/.config/nvim" "Neovim config"
remove_symlink "$HOME/.config/atuin/themes/prom-wiki.toml" "atuin prom-wiki theme"
remove_symlink "$HOME/.config/atuin/themes/prom-lilas.toml" "atuin prom-lilas theme"
remove_symlink "$HOME/.config/bat/themes/prom-wiki.tmTheme" "bat prom-wiki theme"
remove_symlink "$HOME/.config/bat/themes/prom-lilas.tmTheme" "bat prom-lilas theme"
remove_symlink "$HOME/Library/Application Support/resterm/themes/prom-wiki.toml" "resterm prom-wiki theme"
remove_symlink "$HOME/Library/Application Support/resterm/themes/prom-lilas.toml" "resterm prom-lilas theme"
remove_symlink "$HOME/.gitconfig" "git config"
remove_symlink "$HOME/.config/git/ignore" "git global ignore"
remove_symlink "$HOME/.colima/_templates/default.yaml" "Colima template"

echo -e "\n${GREEN}✅ Dotfiles uninstallation completed!${NC}"
echo -e "${YELLOW}🔄 You may need to restart applications for changes to take effect.${NC}"