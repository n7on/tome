# Run NSE script(s) against target
nmap_script_run() {
    _grim_command_requires nmap || return 1
    _grim_command_description "Run NSE script(s) against target"
    _grim_command_param target --required --help "Target host or IP"
    _grim_command_param script --required --help "NSE script name"
    _grim_command_param ports --help "Port range to scan"
    _grim_command_param_parse "$@" || return 1

    local cmd=(nmap --script="$script" "$target")
    [[ -n "$ports" ]] && cmd+=(-p "$ports")

    _grim_command_exec "${cmd[@]}" \
        | awk '/^[0-9]+\//{printf "%s\t%s\t%s\n", $1, $2, $3}' \
        | _grim_command_output_render "port,state,service"
}

# Register completions
_grim_command_complete_params "nmap_script_run" "target" "script" "ports"
