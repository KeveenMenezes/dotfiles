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
	- `config`: Ghostty terminal config. Opens straight into herdr, so reopening Ghostty reattaches to the running agents.
	- `themes/prom-wiki`: Prom-Wiki color theme for Ghostty.

- **herdr/** — [herdr](https://herdr.dev), terminal multiplexer built for AI coding agents
	- `config.toml`: Prometheus theme (promo-wiki palette over the Ghostty ANSI colors, transparent panels), nushell panes, agent sidebar with model/context for Claude, Claude plan quota in the tab bar, popups.
	- `scripts/claude-statusline.sh`: Claude Code `statusLine`. Reports model and context to the herdr sidebar, caches the plan quota (`rate_limits` 5h/7d) and prints a compact line inside Claude Code.
	- `scripts/claude-quota.sh`: tab bar segment that shows the cached quota (`5h 23% ↻ 1h14m · 7d 41%`).

## herdr

Ghostty opens straight into herdr; closing the window only detaches, agents keep running.
Prefix is the default `ctrl+b` (`prefix ?` shows every key).

| Keys | Action |
| --- | --- |
| `prefix c` / `prefix n` / `prefix p` | New / next / previous tab |
| `prefix v` / `prefix -` | Split right / down |
| `prefix h/j/k/l` | Move between panes |
| `prefix z` | Zoom pane |
| `prefix w` / `prefix g` | Workspace picker / goto |
| `prefix shift+n` | New workspace |
| `prefix a` / `prefix shift+a` | Next / previous agent (sidebar is sorted by attention: blocked first) |
| `prefix o` | Jump to the agent from the last notification |
| `prefix b` | Toggle sidebar |
| `prefix f` | Floating shell popup |
| `prefix ctrl+g` / `prefix ctrl+d` | lazygit / lazydocker popup |
| `prefix [` | Copy mode (`v` select, `y` copy) |
| `prefix q` | Detach |
| `prefix shift+r` | Reload config |

### Claude Code setup

```sh
brew install herdr
herdr integration install claude   # session restore after herdr restarts
```

Then point the Claude Code status line at the script in `~/.claude/settings.json`:

```json
"statusLine": { "type": "command", "command": "~/.config/herdr/scripts/claude-statusline.sh", "padding": 0 }
```

The sidebar shows, for each Claude agent: state, where it runs, what it is doing (terminal title) and `model · ctx N%` (green < 50%, orange < 80%, red above, close to auto-compact). The tab bar shows the plan usage of the current 5-hour window, time until it resets and the 7-day usage; it disappears when there is no data.

## Usage

- Copy the contents of `sketchbar/` to your `~/.config/sketchybar` directory to apply the bar configuration.
- Use the `aerospace/default-config.toml` for AeroSpace window manager customization.
- Import the VS Code settings and keybindings for a personalized editor experience.
- Install herdr (`brew install herdr`) and link `ghostty/` and `herdr/` into `~/.config/` (done by `install.sh`).