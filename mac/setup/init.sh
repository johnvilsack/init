#!/bin/bash

set -euo pipefail

# Check for file that prevents installation
if [[ -f "$HOME/.config/init.done" ]]
then
  INIT_NO_INSTALL="$(cat "$HOME/.config/init.done" 2>/dev/null)"
  if [[ -n "${INIT_NO_INSTALL}" ]]
  then
    abort "Init cannot be installed because ${INIT_NO_INSTALL}."
  else
    abort "Init cannot be installed because $HOME/.config/init.done exists!"
  fi
fi

# Install Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "🍺 Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Rosetta is required for Apple Silicon Macs to run x86_64 binaries
if [[ "$(uname -m)" == "arm64" ]] && ! /usr/sbin/softwareupdate --history | grep -q "Rosetta"; then
  echo "Rosetta is not installed. Installing Rosetta..."
  /usr/sbin/softwareupdate --install-rosetta --agree-to-license || echo "Rosetta may already be installed"
else

# Github CLI
if ! command -v gh >/dev/null 2>&1; then
  echo "Installing GitHub CLI..."
  brew install gh
else
  echo "GitHub CLI is already installed."
fi

# Login to GitHub CLI
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo "Already authenticated with GitHub CLI"
else
  gh auth login \
    --hostname github.com \
    --git-protocol https \
    --web
fi

# Clone dotfiles repo now that we're logged in
if [ ! -d "$HOME/github/dotfiles" ]; then
  echo "Cloning dotfiles repository..."
  mkdir -p "$(dirname "$HOME/github/dotfiles")"
  git clone "https://github.com/johnvilsack/dotfiles" "$HOME/github/dotfiles"
  chmod +x "$HOME/github/dotfiles/mac/install.sh"
  bash "$HOME/github/dotfiles/mac/install.sh"
else
  echo "Dotfiles repository already exists at $HOME/github/dotfiles"
fi
