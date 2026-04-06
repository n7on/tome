# Cache management commands

cache_clear() {
    _grim_command_param_parse "$@" || return 1

    if [[ -d "$_GRIM_CACHE_DIR" ]]; then
        rm -rf "$_GRIM_CACHE_DIR"
        _grim_message_warn "Cache cleared"
    fi
}

_grim_command_complete_params "cache_clear" "Clear all cached command output"
