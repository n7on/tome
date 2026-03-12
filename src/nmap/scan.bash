# Quick scan of common ports
nmap_scan_quick() {
    _grim_command_requires nmap || return 1
    
    _grim_command_init target
    _grim_command_parse "$@"

    _grim_command_validate target --required || return 1

    local cmd=(nmap -T4 --top-ports 1000 "$target")
    
    _grim_command_output_set "PORT,STATE,SERVICE" '/^[0-9]+\//{printf "%s\t%s\t%s\n", $1, $2, $3}'
    _grim_command_run "${cmd[@]}" | _grim_command_output_render
}

# Full port scan (all 65535 ports)
nmap_scan_full() {
    _grim_command_requires nmap || return 1
    
    _grim_command_init target
    _grim_command_parse "$@"

    _grim_command_validate target --required || return 1

    local cmd=(nmap -T4 -p- "$target")
    
    _grim_command_output_set "PORT,STATE,SERVICE" '/^[0-9]+\//{printf "%s\t%s\t%s\n", $1, $2, $3}'
    _grim_command_run "${cmd[@]}" | _grim_command_output_render
}

# Service and version detection
nmap_scan_services() {
    _grim_command_requires nmap || return 1
    
    _grim_command_init target ports
    _grim_command_parse "$@"

    _grim_command_validate target --required || return 1

    local cmd=(nmap -sV -sC "$target")
    [[ -n "$ports" ]] && cmd+=(-p "$ports")
    
    _grim_command_output_set "PORT,STATE,SERVICE,VERSION" '/^[0-9]+\//{printf "%s\t%s\t%s\t%s\n", $1, $2, $3, substr($0, index($0,$4))}'
    _grim_command_run "${cmd[@]}" | _grim_command_output_render
}

# OS detection (requires root)
nmap_scan_os() {
    _grim_command_requires nmap || return 1
    
    _grim_command_init target
    _grim_command_parse "$@"

    _grim_command_validate target --required || return 1

    local cmd=(sudo nmap -O "$target")
    
    _grim_command_output_set "TYPE,DETAILS" '/^(OS|Running|Device|Network)/{split($0, a, ":"); gsub(/^[ \t]+|[ \t]+$/, "", a[1]); val=""; for(i=2;i<=length(a);i++){if(i>2)val=val":"; val=val a[i]}; gsub(/^[ \t]+|[ \t]+$/, "", val); print a[1] "\t" val}'
    _grim_command_run "${cmd[@]}" | _grim_command_output_render
}

# Network discovery (ping sweep)
nmap_scan_discover() {
    _grim_command_requires nmap || return 1
    
    _grim_command_init subnet
    _grim_command_parse "$@"

    _grim_command_validate subnet --required || return 1

    local cmd=(nmap -sn "$subnet")
    
    _grim_command_output_set "HOST,STATUS" '/Nmap scan report for/{host=$5} /Host is up/{printf "%s\t%s\n", host, "up"}'
    _grim_command_run "${cmd[@]}" | _grim_command_output_render
}

# Stealth SYN scan
nmap_scan_stealth() {
    _grim_command_requires nmap || return 1
    
    _grim_command_init target ports
    _grim_command_parse "$@"

    _grim_command_validate target --required || return 1

    local cmd=(sudo nmap -sS -T2 "$target")
    [[ -n "$ports" ]] && cmd+=(-p "$ports")
    
    _grim_command_output_set "PORT,STATE,SERVICE" '/^[0-9]+\//{printf "%s\t%s\t%s\n", $1, $2, $3}'
    _grim_command_run "${cmd[@]}" | _grim_command_output_render
}

# UDP scan
nmap_scan_udp() {
    _grim_command_requires nmap || return 1
    
    _grim_command_init target ports=53,67,68,69,123,161,162,500,514,1900
    _grim_command_parse "$@"

    _grim_command_validate target --required || return 1

    local cmd=(sudo nmap -sU -p "$ports" "$target")
    
    _grim_command_output_set "PORT,STATE,SERVICE" '/^[0-9]+\//{printf "%s\t%s\t%s\n", $1, $2, $3}'
    _grim_command_run "${cmd[@]}" | _grim_command_output_render
}

_complete_targets() {
    local cur="$1"
    if [[ "$cur" == */* ]]; then
        # Already typing a subnet, suggest common masks
        local base="${cur%%/*}"
        echo "${base}/8 ${base}/16 ${base}/24"
    else
        # Suggest known hosts from file, fall back to common targets
        if [[ -f ~/.targets ]]; then
            cat ~/.targets
        else
            echo "127.0.0.1 10.0.0.0/24 192.168.1.0/24"
        fi
    fi
}
_grim_command_set_completer "nmap_scan_full" "target" _complete_targets

# Register parameters
_grim_command_set_params "nmap_scan_quick" "target"
_grim_command_set_params "nmap_scan_full" "target"
_grim_command_set_params "nmap_scan_services" "target" "ports"
_grim_command_set_params "nmap_scan_os" "target"
_grim_command_set_params "nmap_scan_discover" "subnet"
_grim_command_set_params "nmap_scan_stealth" "target" "ports"
_grim_command_set_params "nmap_scan_udp" "target" "ports"
