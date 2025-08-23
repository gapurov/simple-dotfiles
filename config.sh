# config.sh

# 1) Symlinks (repo-relative source : absolute-or-tilde destination)
LINKS=(
  # Core developer tooling
  "config/git/gitconfig:~/.gitconfig"
  "config/git/gitignore:~/.gitignore"

  # Shell and editor
  "config/zsh/zshrc:~/.zshrc"
  "config/nvim/init.vim:~/.config/nvim/init.vim"
  "config/tmux.conf:~/.tmux.conf"

  # Optional modular configs (uncomment to use)
  # "config/zsh/aliases:~/.config/zsh/aliases"
  # "config/zsh/exports:~/.config/zsh/exports"

)

# 2) Steps to run (executed in repo root, in order).
#    Each step has a single clear purpose for better maintainability.
STEPS=(
  # Keep submodules in sync (safe if no submodules)
  "git submodule update --init --recursive || true"

  # Check and install essential development tools
  "./scripts/check-tools.sh --auto-install"

  # Create backup of existing configs before installation
  "./scripts/backup-configs.sh || true"

  # Ensure essential directories exist
  "mkdir -p ~/bin ~/.config ~/.local/share"

  # Set zsh as default shell
  "./scripts/set-default-shell.sh || true"

  # Install vim-plug for Neovim plugin management
  "./scripts/install-vim-plug.sh || true"

  # Install Oh My Zsh
  "./scripts/install-omz.sh || true"

  # Ensure scripts are executable and clean up
  "chmod +x scripts/*.sh 2>/dev/null || true"
  "./scripts/clean-temp.sh || true"
)
