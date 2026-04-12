# Introspection commands for rig

# List all registered commands
command_list() {
    _description "List all registered rig commands"
    _param_parse "$@" || return 1

    _exec_python command command_docs.py "$_RIG_DIR/src" --format list \
        | _output_render
}

# Show details of a specific command
command_show() {
    _description "Show parameters for a rig command"
    _param name --required --positional --help "Command name"
    _param_parse "$@" || return 1

    _exec_python command command_docs.py "$_RIG_DIR/src" --format show --command "$name" \
        | _output_render
}

# Generate markdown documentation for all commands
command_docs() {
    _description "Generate markdown documentation for all rig commands"
    _param_parse "$@" || return 1

    _exec_python command command_docs.py "$_RIG_DIR/src" --format docs --bin "rig"
}

_complete_params "command_list"
_complete_params "command_show" "name"
_complete_params "command_docs"

_command_show_complete() {
    # Load all namespaces to get the full command list
    local ns_dir ns
    for ns_dir in "$_RIG_DIR/src"/*/; do
        ns="$(basename "$ns_dir")"
        [[ "$ns" == _* ]] && continue
        _require_module "$ns" 2>/dev/null
    done
    for _vol in "$HOME/.rig/plugin"/*/; do
        [[ -d "$_vol/src" ]] || continue
        for ns_dir in "$_vol/src"/*/; do
            ns="$(basename "$ns_dir")"
            [[ "$ns" == _* ]] && continue
            _require_module "$ns" 2>/dev/null
        done
    done

    local names="" _cmd
    local -A seen
    for _key in "${!_PARAMS[@]}"; do
        _cmd="${_key%%:*}"
        [[ -v seen[$_cmd] ]] && continue
        [[ "$_cmd" == _* ]] && continue
        seen[$_cmd]=1
        names+="$_cmd "
    done
    _complete_filter "$names" "$1"
}
_complete_func "command_show" "name" _command_show_complete
