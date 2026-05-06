# dotfiles

Personal dotfiles for quick setup on a fresh environment.

## Quick Start

### 1. Clone into home directory

```
cd ~
git init
git remote add origin https://github.com/wiresv/dotfiles.git
git fetch origin
git checkout -B main origin/main
source ~/.zshrc
```

### 2. Install all required packages

**Linux (apt):**

```
aptsetup
```

This runs `~/.config/scripts/apt-setup.sh` which installs everything the dotfiles depend on, including packages that need external repos (like eza).

**macOS:**

```
macsetup
```

This runs `~/.config/scripts/mac-setup.sh` which bootstraps Homebrew (if missing), installs `jq` and `node`, and `npm install -g`s any required global CLIs (`fast-cli`).

## Included tools

- **`wifi-speed`** (`~/.local/bin/wifi-speed`, macOS only) — measure WiFi/internet speed against Apple's `networkquality`, Cloudflare, and Netflix Open Connect in one shot. Logs JSONL to `~/.local/share/wifi-speed/log.jsonl` (machine-local, not synced across dotfiles). Run `wifi-speed --help` for flags.
