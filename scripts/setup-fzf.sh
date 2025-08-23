#!/bin/bash
# Setup fzf key bindings and fuzzy completion

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

success() { printf "%b✓ %s%b\n" "$GREEN" "$1" "$NC"; }
warn() { printf "%b⚠ %s%b\n" "$YELLOW" "$1" "$NC"; }
info() { printf "%b  %s%b\n" "$BLUE" "$1" "$NC"; }

# Check if fzf is available
if ! command -v fzf >/dev/null 2>&1; then
    warn "fzf not available, skipping fzf setup"
    exit 0
fi

# Check if fzf is already configured
if [[ -f ~/.fzf.zsh ]]; then
    success "fzf is already configured"
    exit 0
fi

# Try to install fzf bindings via Homebrew
if command -v brew >/dev/null 2>&1; then
    fzf_install="$(brew --prefix)/opt/fzf/install"
    if [[ -f "$fzf_install" ]]; then
        info "Setting up fzf key bindings and completion via Homebrew"
        if "$fzf_install" --key-bindings --completion --no-update-rc 2>/dev/null; then
            success "fzf key bindings and completion configured"
        else
            warn "Failed to configure fzf via Homebrew installer"
        fi
    else
        warn "fzf installer not found via Homebrew"
    fi
else
    warn "Homebrew not available for fzf setup"
fi
