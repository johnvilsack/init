#!/bin/bash

set -euo pipefail

echo "*** SETUP MY MAC ***"

# Install Homebrew
if ! command -v brew >/dev/null 2>&1; then
  echo "[INSTALLING] Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to PATH for Apple Silicon
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# Rosetta is required for Apple Silicon Macs to run x86_64 binaries
if [[ "$(uname -m)" == "arm64" ]] && ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    echo "[INSTALLING] Rosetta"
    sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license 2>/dev/null
fi

# Github CLI
if ! command -v gh >/dev/null 2>&1; then
  echo "[INSTALLING] GitHub CLI"
  brew install gh
fi

# Login to GitHub CLI
#gh auth status --hostname github.com &>/dev/null || echo "Logging in to Github..." && gh auth login --hostname github.com --git-protocol https --web
if ! gh auth status --hostname github.com &>/dev/null; then
    #echo "Already logged in to GitHub"
    echo "[LOGIN] Authorizing GitHub"
    gh auth login --hostname github.com --git-protocol https --web
fi

export GITHUBPATH="$HOME/github"
export DOTFILESPATH="$GITHUBPATH/dotfiles"
export DOTFILESHOME="$DOTFILESPATH/mac/files/home"

# Clone dotfiles repo now that we're logged in
if [ ! -d "$DOTFILESPATH" ]; then
  echo "[CLONING] dotfiles repository"
  mkdir -p "$(dirname "$DOTFILESPATH")"
  git clone "https://github.com/johnvilsack/dotfiles" "$DOTFILESPATH"
  echo "[PERMISSIONS] Setting permissions for dotfiles"
  find "$DOTFILESPATH" -type f -name "*.sh" -exec chmod +x {} \;
fi

if [[ -f "$DOTFILESPATH/mac/mac-install.sh" ]]; then
  echo "[RUNNING] dotfiles install script"
  exec /bin/bash "$DOTFILESPATH/mac/mac-install.sh"
fi