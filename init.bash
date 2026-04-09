_TOME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_TOME_PYTHON="$_TOME_DIR/.venv/bin/python3"

export PATH="$_TOME_DIR/bin:$PATH"

# Set up shell completion
# Run 'tome completion bash' or 'tome completion zsh' to generate the script
