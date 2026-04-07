#!/usr/bin/env bash
set -euo pipefail

_TOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_TOME_USER_DIR="$HOME/.tome"

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

# Create ~/.tome/ if needed
if [[ ! -d "$_TOME_USER_DIR" ]]; then
    echo "Creating $_TOME_USER_DIR..."
    mkdir -p "$_TOME_USER_DIR"
fi

# Create/update virtualenv and install Python dependencies
echo "Installing Python dependencies..."
python3 -m venv "$_TOME_DIR/.venv"
"$_TOME_DIR/.venv/bin/pip" install --quiet --disable-pip-version-check "$_TOME_DIR"

echo ""
echo "Setup complete. Add the following to your .bashrc:"
echo ""
echo "  export PATH=\"$_TOME_DIR/bin:\$PATH\""
echo "  source <(tome completion bash)"
