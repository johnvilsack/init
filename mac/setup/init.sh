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

# Logging env (read by clog once installed)
export CLOG_FILENAME="mac-install.log"
export CLOG_TAG="init"
export CLOG_SHOW_TIMESTAMP=true
export CLOG_DISPLAY_TAG=true

# Legacy colors for pre-clog logging
RED=$'%{\033[0;31m%}'
GREEN=$'%{\033[0;32m%}'
YELLOW=$'%{\033[1;33m%}'
BLUE=$'%{\033[0;34m%}'
NC=$'%{\033[0m%}'

# Ensure zsh sees newly installed commands
refresh_path() { 
    rehash 2>/dev/null || true
}

# Simple logging before clog is available
log_info() {
    printf "%s[INFO]%s %s\n" "$BLUE" "$NC" "${1:-}"
}

log_success() {
    printf "%s[SUCCESS]%s %s\n" "$GREEN" "$NC" "${1:-}"
}

log_warning() {
    printf "%s[WARNING]%s %s\n" "$YELLOW" "$NC" "${1:-}"
}

log_error() {
    printf "%s[ERROR]%s %s\n" "$RED" "$NC" "${1:-}"
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
    
    # Verify clog is available
    if command -v clog >/dev/null 2>&1; then
        clog INFO "clog ENABLED"
    else
        log_error "clog did not install correctly"
    fi
}

# ---- Homebrew ----
get_homebrew() {
    if ! command -v brew >/dev/null 2>&1; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        if [[ "$(uname -m)" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            log_success "Homebrew added to PATH for Apple Silicon"
        else
            eval "$(/usr/local/bin/brew shellenv)"
            log_success "Homebrew added to PATH for Intel Mac"
        fi
        
        refresh_path
        log_success "Homebrew Installed"
    fi
}

# ---- Rosetta (Apple Silicon) ----
get_rosetta() {
    if [[ "$(uname -m)" == "arm64" ]] && ! arch -x86_64 /usr/bin/true 2>/dev/null; then
        clog INFO "Installing Rosetta for x86_64 compatibility..."
        sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license 2>/dev/null
        clog SUCCESS "Rosetta Installed"
    fi
}

# ---- GitHub CLI ----
get_github() {
    if ! command -v gh >/dev/null 2>&1; then
        clog INFO "Installing GitHub CLI..."
        brew install gh
        refresh_path
        clog SUCCESS "GitHub CLI Installed"
    fi
}

login_github() {
    if ! gh auth status --hostname github.com &>/dev/null; then
        clog INFO "Logging in to GitHub..."
        gh auth login --hostname github.com --git-protocol https --web
        if [[ $? -eq 0 ]]; then
            clog SUCCESS "Logged in to GitHub CLI"
        else
            clog ERROR "Failed to log in to GitHub CLI"
            exit 1
        fi
    else
        clog INFO "Already logged in to GitHub"
    fi
}

# ---- Dotfiles ----
get_dotfiles() {
    if [[ ! -d "$DOTFILESPATH" ]]; then
        clog INFO "Cloning dotfiles repository..."
        mkdir -p "$(dirname "$DOTFILESPATH")"
        git clone "https://github.com/johnvilsack/dotfiles" "$DOTFILESPATH"
        if [[ $? -eq 0 ]]; then
            clog SUCCESS "Cloned dotfiles repository"
        else
            clog ERROR "Failed to clone dotfiles repository"
            exit 1
        fi
        
        find "$DOTFILESPATH" -type f -name "*.sh" -exec chmod +x {} \;
        clog SUCCESS "Made scripts executable"
    else
        clog INFO "Dotfiles already present at $DOTFILESPATH"
    fi
}

run_dotfiles_installer() {
    local installer="$DOTFILESPATH/$OS/scripts/$OS-install.sh"
    if [[ -f "$installer" ]]; then
        clog INFO "Running dotfiles install script"
        # shellcheck disable=SC1090
        source "$installer"
    else
        clog WARNING "Dotfiles installer not found at $installer"
    fi
}

# ---- Main installation flow ----
install_main() {
    # First two steps use simple logging since clog isn't available yet
    get_homebrew
    install_macapps
    
    # Everything after this uses clog directly
    get_rosetta
    get_github
    login_github
    get_dotfiles
    run_dotfiles_installer
    
    clog SUCCESS "***** MAC INSTALL COMPLETE! *****"
}

# Run the installer
install_main
