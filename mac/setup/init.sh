#!/bin/bash
#FOOFOO
set -euo pipefail

# Preset vars needed for installer
export OS="mac"
export GITHUBPATH="$HOME/github"
export DOTFILESPATH="$GITHUBPATH/dotfiles"
export DOTFILESHOME="$DOTFILESPATH/$OS/files/HOME"

# Temporary bypass to fix intune issues
export HOMEBREW_BUNDLE_MAS_SKIP=1
export HOMEBREW_FORBIDDEN_CASKS="google-chrome microsoft-teams the-unarchiver"
export HOMEBREW_FORBIDDEN_FORMULAE="mas"

# Logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info "*** SETUP MY MAC! ***"


## MY MACAPPS INSTALLER HERE
function install_macapps() {
    if [[ ! -f "$DOTFILESPATH/$OS/scripts/$OS-install.sh" ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/johnvilsack/macapps/HEAD/install.sh)"
        log_success "macapps installed to $HOME/.local/bin"
    else
        log_info "macapps install script already exists, skipping installation"
    fi
}
exit;
# Install Homebrew
function get_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    if [[ "$(uname -m)" == "arm64" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      log_success "Homebrew added to PATH for Apple Silicon"
    fi
    log_success "Homebrew Installed"
  fi
}

# Rosetta is required for Apple Silicon Macs to run x86_64 binaries
function get_rosetta() {
  if [[ "$(uname -m)" == "arm64" ]] && ! arch -x86_64 /usr/bin/true 2>/dev/null; then
      sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license 2>/dev/null
      log_success "Rosetta Installed"
  fi
}

# Github CLI
function get_github() {
  if ! command -v gh >/dev/null 2>&1; then
    brew install gh
    log_success "GitHub CLI Installed"
  fi
}

# Login to GitHub CLI
function login_github() {
  if ! gh auth status --hostname github.com &>/dev/null; then
      gh auth login --hostname github.com --git-protocol https --web
      if [ $? -eq 0 ]; then
          log_success "Logged in to GitHub CLI"
      else
          log_error "Failed to log in to GitHub CLI"
          exit 1
      fi
  fi
}

# Clone dotfiles repo now that we're logged in
function get_dotfiles() {
  if [ ! -d "$DOTFILESPATH" ]; then
    mkdir -p "$(dirname "$DOTFILESPATH")"
    git clone "https://github.com/johnvilsack/dotfiles" "$DOTFILESPATH"
    if [ $? -eq 0 ]; then
      log_success "Cloned dotfiles repository"
    else
      log_error "Failed to clone dotfiles repository"
      exit 1
    fi
    find "$DOTFILESPATH" -type f -name "*.sh" -exec chmod +x {} \;
    log_success "Made scripts executable"
  fi
}

function run_dotfiles_installer() {
  if [[ -f "$DOTFILESPATH/$OS/scripts/$OS-install.sh" ]]; then
    log_info "Running dotfiles install script"
    source "$DOTFILESPATH/$OS/scripts/$OS-install.sh"
  fi
}

function install_main() {
  install_macapps
  get_homebrew
  # Trying to sunset Rosetta
  #get_rosetta
  get_github
  login_github
  get_dotfiles
  run_dotfiles_installer
}

install_main