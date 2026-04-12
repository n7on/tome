_RIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_RIG_PYTHON="$_RIG_DIR/.venv/bin/python3"

export PATH="$_RIG_DIR/bin:$PATH"

# Set up shell completion
# Run 'rig completion bash' or 'rig completion zsh' to generate the script
