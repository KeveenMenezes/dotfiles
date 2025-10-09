# Dotfiles Repository

This repository contains configuration files and scripts for customizing your development environment on macOS.

## Structure

- **aerospace/**
	- `default-config.toml`: Configuration for the AeroSpace window manager, including workspace and focus change triggers, layout settings, and normalization options.

- **sketchbar/**
	- `sketchybarrc`: Main configuration script for SketchyBar, setting up appearance, colors, icons, helper processes, and plugins.
	- `colors.sh`: Defines color palette variables for SketchyBar.
	- `icons.sh`: Defines icon variables for use in SketchyBar.
	- `items/`: Contains scripts for individual bar items (e.g., battery, CPU, Spotify, etc.).
	- `plugins/`: Contains plugin scripts for extended bar functionality.
	- `helper/`: Contains helper scripts and binaries for SketchyBar.

- **vs-code/**
	- `keybindings.json`: Custom keybindings for Visual Studio Code.
	- `settings.json`: User settings for Visual Studio Code.

## Usage

- Copy the contents of `sketchbar/` to your `~/.config/sketchybar` directory to apply the bar configuration.
- Use the `aerospace/default-config.toml` for AeroSpace window manager customization.
- Import the VS Code settings and keybindings for a personalized editor experience.