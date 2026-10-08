#!/bin/bash

# Dotfiles Installation Script
# This script creates symbolic links from the dotfiles repository to their expected locations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}🚀 Installing dotfiles from: $DOTFILES_DIR${NC}"

# Function to create symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"
    local target_dir="$(dirname "$target")"
    
    # Create target directory if it doesn't exist
    if [ ! -d "$target_dir" ]; then
        echo -e "${YELLOW}📁 Creating directory: $target_dir${NC}"
        mkdir -p "$target_dir"
    fi
    
    # If target already exists, back it up
    if [ -e "$target" ] || [ -L "$target" ]; then
        echo -e "${YELLOW}📦 Backing up existing: $target${NC}"
        mv "$target" "${target}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create symlink
    echo -e "${GREEN}🔗 Linking: $source -> $target${NC}"
    ln -sf "$source" "$target"
}

# SketchyBar Configuration
echo -e "\n${GREEN}🎨 Setting up SketchyBar configuration...${NC}"
SKETCHYBAR_CONFIG_DIR="$HOME/.config/sketchybar"

# Remove existing config directory if it exists and create symlink to entire directory
if [ -d "$SKETCHYBAR_CONFIG_DIR" ]; then
    echo -e "${YELLOW}📦 Backing up existing SketchyBar config${NC}"
    mv "$SKETCHYBAR_CONFIG_DIR" "${SKETCHYBAR_CONFIG_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Create parent directory and symlink
mkdir -p "$(dirname "$SKETCHYBAR_CONFIG_DIR")"
ln -sf "$DOTFILES_DIR/sketchbar" "$SKETCHYBAR_CONFIG_DIR"
echo -e "${GREEN}🔗 Linked entire SketchyBar directory${NC}"

# AeroSpace Configuration
echo -e "\n${GREEN}✈️ Setting up AeroSpace configuration...${NC}"
AEROSPACE_CONFIG_DIR="$HOME/.config/aerospace"
create_symlink "$DOTFILES_DIR/aerospace/default-config.toml" "$AEROSPACE_CONFIG_DIR/aerospace.toml"

# VS Code Configuration
echo -e "\n${GREEN}📝 Setting up VS Code configuration...${NC}"
VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"
create_symlink "$DOTFILES_DIR/vs-code/settings.json" "$VSCODE_CONFIG_DIR/settings.json"
create_symlink "$DOTFILES_DIR/vs-code/keybindings.json" "$VSCODE_CONFIG_DIR/keybindings.json"

# Ghostty Configuration
echo -e "\n${GREEN}👻 Setting up Ghostty configuration...${NC}"
GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
create_symlink "$DOTFILES_DIR/ghostty/config" "$GHOSTTY_CONFIG_DIR/config"
create_symlink "$DOTFILES_DIR/ghostty/themes/prom-wiki" "$GHOSTTY_CONFIG_DIR/themes/prom-wiki"

# herdr Configuration
echo -e "\n${GREEN}🐑 Setting up herdr configuration...${NC}"
HERDR_CONFIG_DIR="$HOME/.config/herdr"
create_symlink "$DOTFILES_DIR/herdr/config.toml" "$HERDR_CONFIG_DIR/config.toml"
create_symlink "$DOTFILES_DIR/herdr/scripts" "$HERDR_CONFIG_DIR/scripts"
if ! command -v herdr >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  herdr not found — install it with: brew install herdr${NC}"
fi
echo -e "${YELLOW}🤖 Claude Code: run 'herdr integration install claude' and set statusLine (see README)${NC}"

echo -e "\n${GREEN}✅ Dotfiles installation completed!${NC}"
echo -e "${YELLOW}📝 Note: Any changes made to files in $DOTFILES_DIR will be automatically reflected in your system configuration.${NC}"
echo -e "${YELLOW}🔄 You may need to restart applications for changes to take effect.${NC}"