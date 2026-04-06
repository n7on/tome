# Introspection commands for grim

# List all registered commands
command_list() {
    _grim_command_param_parse "$@" || return 1

    _grim_command_exec_python command command_docs.py "$_GRIM_DIR/src" --format list \
        | _grim_command_output_render
}

# Show details of a specific command
command_show() {
    _grim_command_param name --required --positional --help "Command name"
    _grim_command_param_parse "$@" || return 1

    _grim_command_exec_python command command_docs.py "$_GRIM_DIR/src" --format show --command "$name" \
        | _grim_command_output_render
}

# Generate markdown documentation for all commands
command_docs() {
    _grim_command_param_parse "$@" || return 1

    _grim_command_exec_python command command_docs.py "$_GRIM_DIR/src" --format docs --grim-bin "grim"
}

_grim_command_complete_params "command_list" "List all registered grim commands"
_grim_command_complete_params "command_show" "Show parameters for a grim command" "name"
_grim_command_complete_params "command_docs" "Generate markdown documentation for all grim commands"

_command_show_complete() {
    local names=""
    local -A seen
    for _key in "${!_GRIM_COMMAND_PARAMS[@]}"; do
        local _cmd="${_key%%:*}"
        [[ -v seen[$_cmd] ]] && continue
        [[ "$_cmd" == _* ]] && continue
        seen[$_cmd]=1
        names+="$_cmd "
    done
    _grim_command_complete_filter "$names" "$1"
}
_grim_command_complete_func "command_show" "name" _command_show_complete
