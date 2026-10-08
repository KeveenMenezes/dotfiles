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

- **ghostty/**
	- `config`: Ghostty terminal config. Opens straight into tmux (`tmux new-session -A -s main`), so reopening Ghostty reattaches to the running agents.
	- `themes/prom-wiki`: Prom-Wiki color theme for Ghostty.

- **tmux/**
	- `tmux.conf`: tmux config for running multiple agents (nushell panes, `C-Space` prefix, vi copy mode, truecolor/extended keys for nvim and Claude Code).
	- `themes/prometheus.conf`: Prometheus theme, derived from the `promo-wiki.nvim` palette and its lualine modes.

## tmux keys

Prefix is `C-Space` (press it twice to send `C-Space` to nvim).

| Keys | Action |
| --- | --- |
| `prefix c` | New window (current dir) |
| `prefix \|` / `prefix -` | Split vertical / horizontal (current dir) |
| `prefix h/j/k/l` | Move between panes |
| `prefix H/J/K/L` | Resize pane (repeatable) |
| `prefix z` | Zoom pane |
| `prefix s` | Pick session |
| `prefix N` | New named session (current dir) |
| `prefix d` | Detach (agents keep running) |
| `prefix [` | Copy mode (`v` select, `C-v` block, `y` copy to clipboard) |
| `prefix r` | Reload config |

The status bar turns peach while the prefix is active and mauve in copy mode; a window whose agent rang the bell turns orange.

## Usage

- Copy the contents of `sketchbar/` to your `~/.config/sketchybar` directory to apply the bar configuration.
- Use the `aerospace/default-config.toml` for AeroSpace window manager customization.
- Import the VS Code settings and keybindings for a personalized editor experience.
- Install tmux (`brew install tmux`) and link `ghostty/` and `tmux/` into `~/.config/` (done by `install.sh`).