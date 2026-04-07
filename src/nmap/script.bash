# Run NSE script(s) against target
nmap_script_run() {
    _requires nmap || return 1
    _param target --required --help "Target host or IP"
    _param script --required --help "NSE script name"
    _param ports --help "Port range to scan"
    _param_parse "$@" || return 1

    local cmd=(nmap --script="$script" "$target")
    [[ -n "$ports" ]] && cmd+=(-p "$ports")

    _exec "${cmd[@]}" \
        | awk '/^[0-9]+\//{printf "%s\t%s\t%s\n", $1, $2, $3}' \
        | _output_render "port,state,service"
}

# Register completions
_complete_params "nmap_script_run" "Run NSE script(s) against target" "target" "script" "ports"
