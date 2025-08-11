#!/usr/bin/env zsh
set -euo pipefail

# Preset vars needed for installer
export PATH="$HOME/.local/bin:$PATH"
export OS="mac"
export GITHUBPATH="$HOME/github"
export DOTFILESPATH="$GITHUBPATH/dotfiles"
export DOTFILESHOME="$DOTFILESPATH/$OS/files/HOME"

# Temporary bypass to fix intune issues
export HOMEBREW_BUNDLE_MAS_SKIP=1
export HOMEBREW_FORBIDDEN_CASKS="google-chrome microsoft-teams the-unarchiver"
export HOMEBREW_FORBIDDEN_FORMULAE="mas"

# Logging env (read by clog if present)
export CLOG_AVAILABLE=false
export CLOG_FILENAME="mac-install.log"
export CLOG_TAG="init"
export CLOG_SHOW_TIMESTAMP=true
export CLOG_DISPLAY_TAG=true

# Legacy colors
RED=$'%{\033[0;31m%}'
GREEN=$'%{\033[0;32m%}'
YELLOW=$'%{\033[1;33m%}'
BLUE=$'%{\033[0;34m%}'
NC=$'%{\033[0m%}'

# Ensure zsh sees newly installed commands
refresh_path() { rehash 2>/dev/null || true; }

# Enable clog if already available
if command -v clog >/dev/null 2>&1; then
  CLOG_AVAILABLE=true
fi

# ---- Smart logging wrappers (tolerate missing message under set -u) ----
log_info() {
  local msg="${1-}"
  if [[ "$CLOG_AVAILABLE" == true ]]; then
    clog INFO "${msg-}"
  else
    printf "%s[INFO]%s %s\n" "$BLUE" "$NC" "${msg-}"
  fi
}
log_success() {
  local msg="${1-}"
  if [[ "$CLOG_AVAILABLE" == true ]]; then
    clog SUCCESS "${msg-}"
  else
    printf "%s[SUCCESS]%s %s\n" "$GREEN" "$NC" "${msg-}"
  fi
}
log_warning() {
  local msg="${1-}"
  if [[ "$CLOG_AVAILABLE" == true ]]; then
    clog WARNING "${msg-}"
  else
    printf "%s[WARNING]%s %s\n" "$YELLOW" "$NC" "${msg-}"
  fi
}
log_error() {
  local msg="${1-}"
  if [[ "$CLOG_AVAILABLE" == true ]]; then
    clog ERROR "${msg-}"
  else
    printf "%s[ERROR]%s %s\n" "$RED" "$NC" "${msg-}"
  fi
}

# ---- Install MacApps (drops clog into ~/.local/bin on success) ----
install_macapps() {
  if [[ ! -f "$HOME/.local/.macapps_last_hash" ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/johnvilsack/macapps/HEAD/install.sh)"
    log_info "***** MAC INSTALL BEGUN! *****"
    log_success "macapps installed to $HOME/.local/bin"
  else
    log_info "***** MAC INSTALL BEGUN! *****"
    log_info "macapps already installed, skipping installation"
  fi

  # Ensure this live zsh sees ~/.local/bin tools
  export PATH="$HOME/.local/bin:$PATH"
  refresh_path

  if command -v clog >/dev/null 2>&1; then
    CLOG_AVAILABLE=true
    clog INFO "clog ENABLED"
  else
    log_error "clog did not install correctly"
  fi
}

# ---- Homebrew ----
get_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ "$(uname -m)" == "arm64" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      log_success "Homebrew added to PATH for Apple Silicon"
    fi
    refresh_path
    log_success "Homebrew Installed"
  fi
}

# ---- Rosetta (Apple Silicon) ----
get_rosetta() {
  if [[ "$(uname -m)" == "arm64" ]] && ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license 2>/dev/null
    log_success "Rosetta Installed"
  fi
}

# ---- GitHub CLI ----
get_github() {
  if ! command -v gh >/dev/null 2>&1; then
    brew install gh
    refresh_path
    log_success "GitHub CLI Installed"
  fi
}

login_github() {
  if ! gh auth status --hostname github.com &>/dev/null; then
    gh auth login --hostname github.com --git-protocol https --web
    if [[ $? -eq 0 ]]; then
      log_success "Logged in to GitHub CLI"
    else
      log_error "Failed to log in to GitHub CLI"
      exit 1
    fi
  fi
}

# ---- Dotfiles ----
get_dotfiles() {
  if [[ ! -d "$DOTFILESPATH" ]]; then
    mkdir -p "$(dirname "$DOTFILESPATH")"
    git clone "https://github.com/johnvilsack/dotfiles" "$DOTFILESPATH"
    if [[ $? -eq 0 ]]; then
      log_success "Cloned dotfiles repository"
    else
      log_error "Failed to clone dotfiles repository"
      exit 1
    fi
    find "$DOTFILESPATH" -type f -name "*.sh" -exec chmod +x {} \;
    log_success "Made scripts executable"
  fi
}

run_dotfiles_installer() {
  local installer="$DOTFILESPATH/$OS/scripts/$OS-install.sh"
  if [[ -f "$installer" ]]; then
    log_info "Running dotfiles install script"
    # shellcheck disable=SC1090
    source "$installer"
  fi
}

install_main() {
  get_homebrew
  install_macapps
  get_rosetta
  get_github
  login_github
  get_dotfiles
  run_dotfiles_installer
  log_success "***** MAC INSTALL COMPLETE! *****"
}

install_main
