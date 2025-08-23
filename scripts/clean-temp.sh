#!/bin/bash
# Clean temporary files and caches from development environment

set -euo pipefail

echo "🧹 Cleaning temporary files and caches..."

cleaned_count=0

# Function to safely remove if exists
safe_remove() {
    local path="$1"
    local description="$2"

    if [[ -e "$path" ]]; then
        echo "🗑️  Removing $description"
        rm -rf "$path"
        ((cleaned_count++))
    fi
}

# Clean common temporary directories
safe_remove ~/.cache "user cache directory"
safe_remove ~/.npm/_logs "npm log files"
safe_remove ~/.npm/_cacache "npm cache"
safe_remove ~/.node_repl_history "Node.js REPL history"
safe_remove ~/.python_history "Python history"
safe_remove ~/.lesshst "less history"
safe_remove ~/.viminfo "Vim info file"

# Clean development tool caches
safe_remove ~/Library/Caches/Homebrew "Homebrew cache (macOS)"
safe_remove ~/.composer/cache "Composer cache"
safe_remove ~/.gradle/caches "Gradle cache"
safe_remove ~/.m2/repository "Maven repository cache"

# Clean temporary files
find /tmp -name ".com.apple.dt.CommandLineTools.*" -delete 2>/dev/null || true
find ~/.local/share/Trash -type f -mtime +30 -delete 2>/dev/null || true

# Clean old log files
find ~/Library/Logs -name "*.log" -mtime +7 -delete 2>/dev/null || true

# # Clean downloads folder of common temporary files
# if [[ -d ~/Downloads ]]; then
#     echo "📥 Cleaning old downloads..."
#     find ~/Downloads -name "*.dmg" -mtime +30 -delete 2>/dev/null || true
#     find ~/Downloads -name "*.zip" -mtime +30 -delete 2>/dev/null || true
#     find ~/Downloads -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || true
# fi

echo "✅ Cleanup complete! Cleaned $cleaned_count items."
echo "💡 Freed up disk space by removing temporary files and old caches."
