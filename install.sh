#!/usr/bin/env bash

set -euo pipefail

# Simple wrapper script that calls run.sh with config.sh
# This maintains the familiar ./install.sh usage pattern

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RUN_SCRIPT="$SCRIPT_DIR/run.sh"
readonly CONFIG_FILE="$SCRIPT_DIR/config.sh"

# Check if run.sh exists
if [[ ! -f "$RUN_SCRIPT" ]]; then
    echo "Error: run.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Check if config.sh exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: config.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

# Execute run.sh with config.sh and pass through all arguments
exec "$RUN_SCRIPT" --config "$CONFIG_FILE" "$@"