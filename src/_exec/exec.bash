# Command execution helpers

# Check that required commands are available
# Usage: _requires jq az curl
_requires() {
    if [[ $# -eq 0 ]]; then
        _message_error "_requires: no commands specified"
        return 1
    fi

    local missing=""

    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+="$cmd "
        fi
    done

    if [[ -n "$missing" ]]; then
        _message_error "Required commands not found: ${missing%% }"
        return 1
    fi
}

# Check that required az extensions are installed, installing any that are missing
# Usage: _requires_az_extension log-analytics resource-graph
_requires_az_extension() {
    if [[ $# -eq 0 ]]; then
        _message_error "_requires_az_extension: no extensions specified"
        return 1
    fi

    for ext in "$@"; do
        if ! az extension show --name "$ext" &>/dev/null; then
            _message_warn "Installing required az extension: $ext"
            az extension add --name "$ext" --only-show-errors || {
                _message_error "Failed to install az extension: $ext"
                return 1
            }
        fi
    done
}

# Handle stderr from _exec calls
# Shows stderr as warnings only with --debug, or always on failure
_exec_stderr() {
    local stderr_file="$1" rc="$2"

    if [[ -s "$stderr_file" ]]; then
        if [[ "${debug:-}" == "true" || $rc -ne 0 ]]; then
            while IFS= read -r line; do
                _message_warn "$line"
            done < "$stderr_file"
        fi
    fi

    rm -f "$stderr_file"
}

# Run a Python script from a namespace's python/ directory, capturing stderr as warnings
# Usage: _exec_python <namespace> <script.py> [args...]
_exec_python() {
    if [[ $# -lt 2 ]]; then
        _message_error "_exec_python: usage: _exec_python <namespace> <script.py> [args...]"
        return 1
    fi

    local namespace="$1"
    local script="$2"
    shift 2

    if [[ ! -x "$_RIG_PYTHON" ]]; then
        _message_error "Python venv not found. Run setup.bash first."
        return 1
    fi

    local script_path="$_RIG_DIR/src/$namespace/python/$script"
    if [[ ! -f "$script_path" ]]; then
        _message_error "Python script not found: $script_path"
        return 1
    fi

    local stderr_file
    stderr_file=$(mktemp)

    _cache_wrap "${cache:-0}" "$_RIG_PYTHON" "$script_path" "$@" 2>"$stderr_file"

    local rc=$?
    _exec_stderr "$stderr_file" "$rc"
    return "$rc"
}

# Run a command array with caching and stderr capture
# Usage: _exec "${cmd[@]}"
_exec() {
    if [[ $# -eq 0 ]]; then
        _message_error "_exec: no command specified"
        return 1
    fi

    local stderr_file
    stderr_file=$(mktemp)

    _cache_wrap "${cache:-0}" "$@" 2>"$stderr_file"

    local rc=$?
    _exec_stderr "$stderr_file" "$rc"
    return "$rc"
}
