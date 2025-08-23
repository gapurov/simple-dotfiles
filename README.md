# Simple Dotfiles

Very simple dotfiles installer.

## Core Files

- `config.sh` - configuration file defining symlinks and installation steps
- `run.sh` - main installer that processes config and creates symlinks
- `install.sh` - convenient wrapper script (recommended entry point)

Example configs in `config/` and `scripts/` directories show typical usage patterns - customize them for your setup.

## Usage

Fork this repository or copy the main files to get started.

### Basic Commands

```bash
./install.sh                   # Full installation
./install.sh --dry-run          # Preview changes without executing
./install.sh --verbose          # Detailed output with debug info
./run.sh -c config.sh          # Use run.sh directly with specific config
```

## Configuration

### LINKS Array

- Format: `"repo-relative-source:absolute-or-~-destination"`
- Source paths relative to repository root
- Destinations support `~` for home directory or absolute paths
- Comments allowed with `#` prefix

### STEPS Array

- Shell commands executed sequentially from repository root
- 5-minute timeout per step (when `timeout`/`gtimeout` available)
- Use `|| true` for optional steps that may fail
- Avoid interactive commands
- Comments allowed with `#` prefix

## License

This project is in the public domain. Feel free to use, modify, and distribute as needed.

## Inspiration

This dotfiles installer draws inspiration from tools like [dotbot](https://github.com/anishathalye/dotbot) but emphasizes simplicity and minimal dependencies.
