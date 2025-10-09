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
    local backup=$(ls -td "${SKETCHYBAR_CONFIG_DIR}.backup."* 2>/dev/null | head -n1)
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

echo -e "\n${GREEN}✅ Dotfiles uninstallation completed!${NC}"
echo -e "${YELLOW}🔄 You may need to restart applications for changes to take effect.${NC}"