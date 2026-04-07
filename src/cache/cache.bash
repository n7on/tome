# Cache management commands

cache_clear() {
    _param_parse "$@" || return 1

    if [[ -d "$_CACHE_DIR" ]]; then
        rm -rf "$_CACHE_DIR"
        _message_warn "Cache cleared"
    fi
}

_complete_params "cache_clear" "Clear all cached command output"
