#!/bin/bash
# Install vim-plug for Neovim plugin management

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

success() { printf "%b✓ %s%b\n" "$GREEN" "$1" "$NC"; }
warn() { printf "%b⚠ %s%b\n" "$YELLOW" "$1" "$NC"; }

# Check if neovim is available
if ! command -v nvim >/dev/null 2>&1; then
    warn "nvim not available, skipping vim-plug installation"
    exit 0
fi

# Check if vim-plug is already installed for Neovim
nvim_autoload_dir="$HOME/.local/share/nvim/site/autoload"
if [[ -f "$nvim_autoload_dir/plug.vim" ]]; then
    success "vim-plug is already installed for Neovim"
    exit 0
fi

# Install vim-plug for Neovim
if curl -fLo "$nvim_autoload_dir/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim 2>/dev/null; then
    success "vim-plug installed successfully for Neovim"
else
    warn "Failed to install vim-plug for Neovim"
    exit 1
fi