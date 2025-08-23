#!/usr/bin/env bash

set -euo pipefail

# Configuration
readonly SCRIPT_VERSION="3.1.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

# Global variables for configuration
CONFIG_FILE=""
REPO_DIR=""

# Colors
readonly BLUE='\033[1m\033[34m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m'

# Global flags
DRY_RUN=false
VERBOSE=false
LINKS_ONLY=false
STEPS_ONLY=false
CONFIG_FROM_STDIN=false

# Global variables
LINKS_PROCESSED=0
STEPS_PROCESSED=0
ERRORS_COUNT=0

# External utilities

# Track whether to show summary on exit
SHOW_SUMMARY=0
LOCK_DIR="$HOME/.dotfiles-install.lock"
LOCK_HELD=0

acquire_lock() {
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        LOCK_HELD=1
        debug "Acquired lock: $LOCK_DIR"
        return 0
    else
        error "Another installation appears to be running (lock present: $LOCK_DIR)"
        return 1
    fi
}

release_lock() {
    if [[ "$LOCK_HELD" -eq 1 ]]; then
        rmdir "$LOCK_DIR" 2>/dev/null || rm -rf "$LOCK_DIR" 2>/dev/null || true
        debug "Released lock: $LOCK_DIR"
    fi
}

# Utility helpers
have() { command -v "$1" >/dev/null 2>&1; }

copy_preserve() {
    # Prefer rsync if available; fallback to portable cp flags
    # Usage: copy_preserve <source> <dest>
    local src="$1" dst="$2"
    if have rsync; then
        rsync -a -- "$src" "$dst"
    else
        # -p preserve mode,ownership,timestamps; -P do not follow symlinks (BSD/macOS); -R recursive
        cp -pPR "$src" "$dst"
    fi
}

# Logging functions (concise)
log() { printf "%b==> %s%b\n" "$BLUE" "$1" "$NC"; }
success() { printf "%b✓ %s%b\n" "$GREEN" "$1" "$NC"; }
warn() { printf "%b⚠ %s%b\n" "$YELLOW" "$1" "$NC" >&2; }
error() { printf "%b✗ %s%b\n" "$RED" "$1" "$NC" >&2; ERRORS_COUNT=$((ERRORS_COUNT + 1)); }
info() { printf "%b  %s%b\n" "$GRAY" "$1" "$NC"; }
debug() { [[ "$VERBOSE" == true ]] && printf "%b[DEBUG] %s%b\n" "$GRAY" "$1" "$NC" >&2 || true; }

determine_config() {
    debug "Determining configuration source..."

    if [[ -n "$CONFIG_FILE" ]]; then
        # Config file specified via CLI
        if [[ ! -f "$CONFIG_FILE" ]]; then
            error "Specified config file not found: $CONFIG_FILE"
            return 1
        fi
        REPO_DIR="$(cd "$(dirname "$CONFIG_FILE")" && pwd)"
        debug "Using explicit config file: $CONFIG_FILE"
    elif [[ "$CONFIG_FROM_STDIN" == true ]]; then
        # Read config from stdin
        CONFIG_FILE="$(mktemp)"
        cat > "$CONFIG_FILE"
        REPO_DIR="$SCRIPT_DIR"
        debug "Reading config from stdin, using script dir as repo: $REPO_DIR"
    else
        # Fall back to default config file in script directory when present
        if [[ -f "$SCRIPT_DIR/config.sh" ]]; then
            CONFIG_FILE="$SCRIPT_DIR/config.sh"
            REPO_DIR="$SCRIPT_DIR"
            debug "Using default config: $CONFIG_FILE"
        else
            error "No config file specified. Use -c option or provide config via stdin."
            return 1
        fi
    fi

    # Convert to absolute path
    CONFIG_FILE="$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")"
    debug "Final config: $CONFIG_FILE, repo: $REPO_DIR"
}

show_help() {
    cat << 'EOF'
Dotfiles Installation Script

USAGE:
    ./run.sh [OPTIONS]

OPTIONS:
    -c, --config <file>   Specify configuration file (optional)
    -d, --dry-run         Show what would be done without executing
    -v, --verbose         Enable verbose output with debug information
    --links-only          Process only symlinks (skip steps)
    --steps-only          Process only steps (skip symlinks)
    -h, --help           Show this help message

EXAMPLES:
    ./run.sh -c config.sh                 # Run with specific config file
    cat config.sh | ./run.sh              # Run with piped config
    ./run.sh -c config.sh --dry-run       # Preview changes without executing
    ./run.sh -c config.sh --verbose       # Detailed installation with debug info
    ./run.sh -c config.sh --dry-run -v    # Preview with verbose output
    ./run.sh --links-only --dry-run       # Only evaluate symlink changes

DESCRIPTION:
    This script reads configuration and performs:
    1. Creates symbolic links for dotfiles
    2. Executes installation steps in order
    3. Creates backups of existing files when necessary
    4. Provides idempotent operation (safe to run multiple times)

    Configuration can be provided via:
    - Explicit file with -c/--config option
    - Piped input via stdin
    - Default config.sh in script directory

EOF
}

validate_environment() {
    debug "Validating environment..."

    # Determine config source first
    determine_config || return 1

    # Check if we're in the right directory
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        warn "Not in a git repository. Some features may not work correctly."
    fi

    debug "Environment validation complete"
}

load_configuration() {
    debug "Loading configuration from: $CONFIG_FILE"

    # Source the configuration file to load LINKS and STEPS arrays
    # shellcheck source=config.sh
    source "$CONFIG_FILE"

    # Validate that required arrays exist and are arrays (Bash 3.2 compatible)
    if [[ -z ${LINKS+x} ]]; then
        error "LINKS array not found in configuration file"
        return 1
    fi
    if ! declare -p LINKS >/dev/null 2>&1 || [[ $(declare -p LINKS 2>/dev/null) != declare\ -a* ]]; then
        error "LINKS must be an array in configuration file"
        return 1
    fi

    if [[ -z ${STEPS+x} ]]; then
        warn "No STEPS defined in configuration; proceeding with links only"
        STEPS=()
    else
        if ! declare -p STEPS >/dev/null 2>&1 || [[ $(declare -p STEPS 2>/dev/null) != declare\ -a* ]]; then
            error "STEPS must be an array in configuration file"
            return 1
        fi
    fi

    debug "Configuration loaded: ${#LINKS[@]} links, ${#STEPS[@]} steps"
}

# Resolve a path to an absolute path, optionally relative to a base directory
resolve_absolute_path() {
    local input_path="$1"
    local base_dir="${2:-}"

    if have python3; then
        python3 - "$base_dir" "$input_path" <<'PY'
import os, sys
base, p = sys.argv[1], sys.argv[2]
if base:
    os.chdir(base)
print(os.path.realpath(p))
PY
        return 0
    fi

    if have perl; then
        perl -MCwd=realpath -e 'use Cwd qw(realpath); my($base,$p)=@ARGV; chdir $base if $base; print realpath($p);' "$base_dir" "$input_path"
        return 0
    fi

    if have realpath; then
        if [[ -n "$base_dir" ]]; then
            (cd "$base_dir" 2>/dev/null && realpath "$input_path")
        else
            realpath "$input_path"
        fi
        return 0
    fi

    if [[ -n "$base_dir" ]]; then
        (cd "$base_dir" 2>/dev/null && printf "%s" "$PWD/$input_path")
    else
        printf "%s" "$input_path"
    fi
    return 0
}

# Determine whether a symlink points to the expected absolute path target
symlink_points_to() {
    local link_path="$1"
    local expected_abs="$2"
    local link_dir target resolved
    link_dir="$(dirname "$link_path")"
    target="$(readlink "$link_path")" || return 1
    resolved="$(resolve_absolute_path "$target" "$link_dir")" || return 1
    [[ "$resolved" == "$expected_abs" ]]
}

backup_file() {
    local file_path="$1"

    if [[ -e "$file_path" ]]; then
        # Create backup directory if it doesn't exist
        if [[ ! -d "$BACKUP_DIR" ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                ( umask 077; mkdir -p "$BACKUP_DIR" )
                debug "Created backup directory: $BACKUP_DIR"
            fi
        fi

        # Preserve original path structure inside backup directory
        local relative_path="${file_path#/}"
        local backup_path="$BACKUP_DIR/$relative_path"

        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$(dirname "$backup_path")"
            copy_preserve "$file_path" "$backup_path"
            info "Backed up: $file_path -> $backup_path"
        else
            info "Would backup: $file_path -> $backup_path"
        fi
        return 0
    fi
    return 1
}

create_symlink() {
    local source_rel="$1"
    local target_path="$2"

    # Convert relative source to absolute path (relative to repo root)
    local source_abs="$REPO_DIR/$source_rel"
    local source_real
    source_real="$(resolve_absolute_path "$source_abs")"
    local target_abs
    target_abs="${target_path/#\~/$HOME}"

    debug "Processing symlink: $source_rel -> $target_path"

    # Check if source exists
    if [[ ! -e "$source_abs" ]]; then
        warn "Source file doesn't exist: $source_abs"
        return 1
    fi

    # Create target directory if needed
    local target_dir
    target_dir="$(dirname "$target_abs")"
    if [[ ! -d "$target_dir" ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$target_dir"
            debug "Created directory: $target_dir"
        else
            info "Would create directory: $target_dir"
        fi
    fi

    # Handle existing target
    if [[ -L "$target_abs" ]]; then
        # It's a symlink - check if it points to the right place (resolve relative targets)
        if symlink_points_to "$target_abs" "$source_real"; then
            debug "Symlink already exists and is correct: $target_abs"
            return 0
        else
            # Backup the incorrect symlink
            local current_target
            current_target="$(resolve_absolute_path "$(readlink "$target_abs")" "$(dirname "$target_abs")")" || current_target="(unresolved)"
            debug "Symlink mismatch: current -> $current_target, expected -> $source_real"
            backup_file "$target_abs"
            if [[ "$DRY_RUN" == false ]]; then
                rm "$target_abs"
                debug "Removed incorrect symlink: $target_abs"
            else
                info "Would remove incorrect symlink: $target_abs"
            fi
        fi
    elif [[ -e "$target_abs" ]]; then
        # It's a regular file/directory - back it up
        # Only backup if it's not identical content for regular files
        local do_backup=1
        if [[ -f "$target_abs" && -f "$source_abs" ]]; then
            if cmp -s "$target_abs" "$source_abs" 2>/dev/null; then
                do_backup=0
                debug "Existing file identical to source; skipping backup: $target_abs"
            fi
        fi

        if [[ $do_backup -eq 1 ]]; then
            backup_file "$target_abs"
        fi

        if [[ "$DRY_RUN" == false ]]; then
            rm -rf "$target_abs"
            debug "Removed existing file: $target_abs"
        else
            info "Would remove existing file: $target_abs"
        fi
    fi

    # Create the symlink
    if [[ "$DRY_RUN" == false ]]; then
        ln -s "$source_abs" "$target_abs"
        success "Created symlink: $source_rel -> $target_path"
    else
        info "Would create symlink: $source_rel -> $target_path"
    fi

    return 0
}

process_symlinks() {
    log "Processing symbolic links..."

    for link_spec in "${LINKS[@]}"; do
        if [[ -z "$link_spec" ]]; then
            continue
        fi

        # Skip comments
        if [[ "$link_spec" =~ ^[[:space:]]*# ]]; then
            debug "Skipping comment: $link_spec"
            continue
        fi

        # Validate that a colon exists in the spec
        if [[ "$link_spec" != *:* ]]; then
            error "Invalid link specification (no colon found): $link_spec"
            continue
        fi

        # Split on the first colon
        local source="${link_spec%%:*}"
        local target="${link_spec#*:}"

        if create_symlink "$source" "$target"; then
            LINKS_PROCESSED=$((LINKS_PROCESSED + 1))
        fi
    done

    if [[ $LINKS_PROCESSED -gt 0 ]]; then
        success "Processed $LINKS_PROCESSED symbolic links"
    else
        warn "No symbolic links were processed"
    fi
}

execute_step() {
    local step_command="$1"

    debug "Executing step: $step_command"

    if [[ "$DRY_RUN" == false ]]; then
        # Change to repository root for execution
        if ! cd "$REPO_DIR"; then
            error "Failed to change to repository directory: $REPO_DIR"
            return 1
        fi

        # Execute step with strict shell options
        local exit_code=0
        local bash_opts=(-euo pipefail)
        if [[ "$VERBOSE" == true ]]; then
            bash_opts+=(-x)
        fi
        if bash "${bash_opts[@]}" -c "$step_command"; then
            success "Completed step: $step_command"
            STEPS_PROCESSED=$((STEPS_PROCESSED + 1))
            return 0
        else
            exit_code=$?
            error "Step failed (exit code: $exit_code): $step_command"
            return $exit_code
        fi
    else
        STEPS_PROCESSED=$((STEPS_PROCESSED + 1))
        return 0
    fi
}

process_steps() {
    log "Processing installation steps..."

    if [[ "$DRY_RUN" == true ]]; then
        info "DRY RUN: Showing all installation steps that would be executed:"
    fi

    for step in "${STEPS[@]}"; do
        if [[ -z "$step" ]]; then
            continue
        fi

        # Skip steps that start with # (comments)
        if [[ "$step" =~ ^[[:space:]]*# ]]; then
            debug "Skipping comment: $step"
            continue
        fi

        if [[ "$DRY_RUN" == true ]]; then
            info "  → $step"
        fi

        execute_step "$step"
    done

    if [[ $STEPS_PROCESSED -gt 0 ]]; then
        success "Processed $STEPS_PROCESSED installation steps"
    else
        warn "No installation steps were processed"
    fi
}

show_summary() {
    log "Installation Summary"
    printf "  Symbolic links: %d\n" "$LINKS_PROCESSED"
    printf "  Installation steps: %d\n" "$STEPS_PROCESSED"
    printf "  Errors: %d\n" "$ERRORS_COUNT"

    if [[ -d "$BACKUP_DIR" ]]; then
        info "Backups saved to: $BACKUP_DIR"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        info "This was a dry run - no changes were made"
    fi
}

# Cleanup function for temporary files
cleanup_temp_files() {
    if [[ "$CONFIG_FROM_STDIN" == true ]] && [[ -n "$CONFIG_FILE" ]] && [[ -f "$CONFIG_FILE" ]]; then
        debug "Cleaning up temporary config file: $CONFIG_FILE"
        rm -f "$CONFIG_FILE"
    fi
}

# Ensure summary is printed and cleanup is performed on any exit path
trap 'if [[ "$SHOW_SUMMARY" -eq 1 ]]; then release_lock; cleanup_temp_files; show_summary; else release_lock; cleanup_temp_files; fi' EXIT

main() {
    SHOW_SUMMARY=1
    log "Dotfiles Installation Script (v$SCRIPT_VERSION)"

    if [[ "$DRY_RUN" == true ]]; then
        warn "DRY RUN MODE - No changes will be made"
    fi

    validate_environment || exit 1
    load_configuration || exit 1
    acquire_lock || exit 1

    if [[ "$STEPS_ONLY" == false ]]; then
        process_symlinks
    else
        debug "Skipping symlink processing (--steps-only)"
    fi

    if [[ "$LINKS_ONLY" == false ]]; then
        process_steps
    else
        debug "Skipping installation steps (--links-only)"
    fi

    if [[ $ERRORS_COUNT -gt 0 ]]; then
        error "Installation completed with $ERRORS_COUNT errors"
        exit 1
    else
        success "Installation completed successfully!"
        exit 0
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        -c|--config)
            if [[ -z "${2:-}" ]]; then
                error "Config file argument required for -c/--config"
                exit 1
            fi
            CONFIG_FILE="$2"
            shift 2 ;;
        -d|--dry-run)
            DRY_RUN=true
            shift ;;
        -v|--verbose)
            VERBOSE=true
            shift ;;
        --links-only)
            LINKS_ONLY=true
            shift ;;
        --steps-only)
            STEPS_ONLY=true
            shift ;;
        -h|--help)
            show_help
            exit 0 ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1 ;;
    esac
done

# Check if we should read from stdin (no config file specified and stdin is not a tty)
if [[ -z "$CONFIG_FILE" ]] && [[ ! -t 0 ]]; then
    if [[ -p /dev/stdin || -s /dev/stdin ]]; then
        CONFIG_FROM_STDIN=true
    fi
fi

# Validate mutually exclusive flags
if [[ "$LINKS_ONLY" == true && "$STEPS_ONLY" == true ]]; then
    error "--links-only and --steps-only cannot be used together"
    exit 2
fi

# If still no config and stdin is a tty, try default config in script dir
if [[ -z "$CONFIG_FILE" ]] && [[ -t 0 ]]; then
    if [[ -f "$SCRIPT_DIR/config.sh" ]]; then
        CONFIG_FILE="$SCRIPT_DIR/config.sh"
    fi
fi

# Run main function
main "$@"
