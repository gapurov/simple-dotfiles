# Simple Dotfiles

Very simple dotfiles boostrap inspired by [dotbot](https://github.com/anishathalye/dotbot).

## Core Files

- `config.sh` - configuration file defining symlinks and installation steps
- `run.sh` - main installer that processes config and creates symlinks
- `install.sh` - convenient wrapper script (recommended entry point)

Example configs in `config/` and `scripts/` directories show typical usage patterns - customize them for your setup.

## Usage

Fork this repository or copy the main files to get started.

### Basic Commands

```bash
./install.sh                   # Full installation (uses config.sh)
./install.sh --dry-run          # Preview changes without executing
./install.sh --verbose          # Detailed output with debug info
./run.sh -c config.sh          # Use run.sh directly with specific config
cat config.sh | ./run.sh       # Pipe config via stdin
./run.sh --links-only          # Only process symlinks (skip steps)
./run.sh --steps-only          # Only run steps (skip symlinks)
```

## Configuration

Configuration can be provided via:

- **Parameter**: `./run.sh -c config.sh`
- **Pipe**: `cat config.sh | ./run.sh`
- **Default**: `config.sh` in the same directory as `run.sh` (auto-detected)

**Config structure**

```bash
  INIT=(
    "initialization_command"
    "setup_command"
  )
  LINKS=(
    "source:target"
    "source2:target2"
  )
  STEPS=(
    "command"
    "command2"
  )
```

### INIT Array

- Initialization commands executed before everything else
- Run in current shell to preserve environment changes (unlike STEPS)
- Perfect for sudo management, environment variables, prerequisites
- Comments allowed with `#` prefix
- **Optional** - if not defined, installation proceeds normally

### LINKS Array

- Format: `"repo-relative-source:absolute-or-~-destination"`
- Source paths relative to repository root
- Destinations support `~` for home directory or absolute paths
- Comments allowed with `#` prefix

### STEPS Array

- Shell commands executed sequentially from repository root
- Use `|| true` for optional steps that may fail
- Avoid interactive commands
- Comments allowed with `#` prefix

## Behavior

- **Execution Order**: INIT → LINKS → STEPS (initialization runs before acquiring lock)
- **Environment Preservation**: INIT commands run in current shell, preserving environment variables
- **Backups**: Existing files are backed up to `~/.dotfiles-backup-YYYYmmdd-HHMMSS/` preserving original paths. Prefers `rsync -a` if available, falls back to portable `cp -pPR`.
- **Idempotency**: Correct existing symlinks are left untouched. Regular files identical to sources are not backed up again before replacement.
- **Locking**: Prevents concurrent runs using `~/.dotfiles-install.lock`. If a previous run crashed, remove the lock directory to proceed.

## License

This project is in the public domain. Feel free to use, modify, and distribute as needed.

## Inspiration

This dotfiles installer draws inspiration from tools like [dotbot](https://github.com/anishathalye/dotbot) but emphasizes simplicity and minimal dependencies.
