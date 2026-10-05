#!/bin/bash
# Install all apt packages required by dotfiles
set -euo pipefail

# Use sudo if available, otherwise run directly (e.g. root in Docker)
if command -v sudo &>/dev/null; then
  SUDO="sudo"
else
  SUDO=""
fi

$SUDO apt update

# Standard packages
$SUDO apt install -y bat git vim tmux zsh less python3 postgresql-client curl build-essential xterm gpg wget jq fzf zoxide

# eza - requires external repo
if ! command -v eza &>/dev/null; then
  echo "Installing eza from deb.gierens.de..."
  $SUDO mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | $SUDO gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | $SUDO tee /etc/apt/sources.list.d/gierens.list
  $SUDO chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  $SUDO apt update
  $SUDO apt install -y eza
else
  echo "eza is already installed."
fi

if [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
  echo "Adding the gh repository from cli.github.com..."
  $SUDO mkdir -p /etc/apt/keyrings
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list
  $SUDO chmod 644 /etc/apt/keyrings/githubcli-archive-keyring.gpg /etc/apt/sources.list.d/github-cli.list
  $SUDO apt update
fi
$SUDO apt install -y gh

echo "All packages installed."
