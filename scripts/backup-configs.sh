#!/bin/bash
# Backup existing configuration files before dotfiles installation

set -euo pipefail

BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

echo "💾 Creating backup of existing configurations..."
echo "Backup directory: $BACKUP_DIR"

# Files to backup
config_files=(
    ~/.gitconfig
    ~/.gitignore
    ~/.zshrc
    ~/.bashrc
    ~/.vimrc
    ~/.tmux.conf
    ~/.inputrc
    ~/.ssh/config
)

# Create backup directory
mkdir -p "$BACKUP_DIR"

backed_up=0
for file in "${config_files[@]}"; do
    if [[ -f "$file" ]] && [[ ! -L "$file" ]]; then
        echo "📁 Backing up $(basename "$file")"
        cp "$file" "$BACKUP_DIR/"
        ((backed_up++))
    elif [[ -L "$file" ]]; then
        echo "🔗 Skipping symlink: $(basename "$file")"
    fi
done

# Backup entire config directories if they exist
config_dirs=(
    ~/.config/git
    ~/.config/zsh
    ~/.vim
)

for dir in "${config_dirs[@]}"; do
    if [[ -d "$dir" ]] && [[ ! -L "$dir" ]]; then
        echo "📂 Backing up directory: $(basename "$dir")"
        cp -r "$dir" "$BACKUP_DIR/"
        ((backed_up++))
    fi
done

if [[ $backed_up -gt 0 ]]; then
    echo "✅ Backed up $backed_up items to $BACKUP_DIR"
else
    echo "ℹ️  No configuration files found to backup"
    rmdir "$BACKUP_DIR"
fi