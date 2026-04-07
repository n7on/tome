# Introspection commands for tome

# List all registered commands
command_list() {
    _param_parse "$@" || return 1

    _exec_python command command_docs.py "$_TOME_DIR/src" --format list \
        | _output_render
}

# Show details of a specific command
command_show() {
    _param name --required --positional --help "Command name"
    _param_parse "$@" || return 1

    _exec_python command command_docs.py "$_TOME_DIR/src" --format show --command "$name" \
        | _output_render
}

# Generate markdown documentation for all commands
command_docs() {
    _param_parse "$@" || return 1

    _exec_python command command_docs.py "$_TOME_DIR/src" --format docs --bin "tome"
}

_complete_params "command_list" "List all registered tome commands"
_complete_params "command_show" "Show parameters for a tome command" "name"
_complete_params "command_docs" "Generate markdown documentation for all tome commands"

_command_show_complete() {
    local names=""
    local -A seen
    for _key in "${!_PARAMS[@]}"; do
        local _cmd="${_key%%:*}"
        [[ -v seen[$_cmd] ]] && continue
        [[ "$_cmd" == _* ]] && continue
        seen[$_cmd]=1
        names+="$_cmd "
    done
    _complete_filter "$names" "$1"
}
_complete_func "command_show" "name" _command_show_complete
