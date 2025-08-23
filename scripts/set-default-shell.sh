#!/bin/bash
# Set default shell to zsh if available

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

success() { printf "%b✓ %s%b\n" "$GREEN" "$1" "$NC"; }
warn() { printf "%b⚠ %s%b\n" "$YELLOW" "$1" "$NC"; }

# Check if zsh is available
if ! command -v zsh >/dev/null 2>&1; then
    warn "zsh not available, skipping shell change"
    exit 0
fi

# Check if zsh is already the default shell
if [[ "$SHELL" == */zsh ]]; then
    success "zsh is already the default shell"
    exit 0
fi

# Try to set zsh as default shell
zsh_path=$(which zsh)

if chsh -s "$zsh_path" 2>/dev/null; then
    success "Default shell changed to zsh"
elif echo "$USER:$zsh_path" | sudo chpass -s "$zsh_path" "$USER" 2>/dev/null; then
    success "Default shell changed to zsh (via chpass)"
else
    warn "Could not set zsh as default shell automatically"
    warn "You may need to run: chsh -s $zsh_path"
fi