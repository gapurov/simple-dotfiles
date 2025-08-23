# Simple Dotfiles

Very simple dotfiles installer.

main files:

- `config.sh` - configuration file containing the links and steps
- `run.sh` - script that reads `config.sh`, creates symlinks and executes steps
- `install.sh` - wrapper that calls `run.sh` with `config.sh` (optional)

configs in `config/` and `scripts/` directory are examples how it can be used, adjust them to your needs.

Usage:
You can copy the main files or fork this repository

Basic usage:

```bash
./run.sh -c config.sh          # Run with config
./install.sh --dry-run          # Preview changes without executing
./install.sh --verbose          # Detailed installation with debug info
```

#### LINKS Array

- Format: `"repo-relative-source:absolute-or-~-destination"`
- Source paths are relative to your repository root
- Destination paths can use `~` for home directory
- Use absolute paths for destinations outside home directory
- Comments supported with `#` prefix

#### STEPS Array

- Shell commands executed in order from repository root
- 5-minute timeout per step (when `timeout`/`gtimeout` available)
- Use `|| true` suffix for optional steps
- Avoid commands that require user interaction
- Comments supported with `#` prefix

## License

This project is in the public domain. Feel free to use, modify, and distribute as needed.

## Inspiration

This dotfiles installer takes inspiration from tools like [dotbot](https://github.com/anishathalye/dotbot) but focuses on:
