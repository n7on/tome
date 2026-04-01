#!/usr/bin/env bash
set -euo pipefail

_GRIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_GRIM_USER_DIR="$HOME/.grim"

# Check for python3
if ! command -v python3 &>/dev/null; then
    echo "Error: python3 is not installed." >&2
    exit 1
fi

# Check for python3-venv
if ! python3 -c "import ensurepip" &>/dev/null; then
    echo "Error: python3-venv is not installed. Run: sudo apt install python3-venv" >&2
    exit 1
fi

# Create ~/.grim/ if needed
if [[ ! -d "$_GRIM_USER_DIR" ]]; then
    echo "Creating $_GRIM_USER_DIR..."
    mkdir -p "$_GRIM_USER_DIR"
fi

# Create/update virtualenv and install Python dependencies
echo "Installing Python dependencies..."
python3 -m venv "$_GRIM_DIR/.venv"
"$_GRIM_DIR/.venv/bin/pip" install --quiet "$_GRIM_DIR"

echo ""
echo "Setup complete. Add the following line to your .bashrc:"
echo ""
echo "  source $_GRIM_DIR/src/init.bash"
