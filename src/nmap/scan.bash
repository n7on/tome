# Quick scan of common ports
nmap_scan_quick() {
    _requires nmap || return 1
    _param target --required --positional --help "Target host or IP"
    _param_parse "$@" || return 1

    _exec nmap -T4 --top-ports 1000 "$target" \
        | awk '/^[0-9]+\//{printf "%s\t%s\t%s\n", $1, $2, $3}' \
        | _output_render "port,state,service"
}

# Full port scan (all 65535 ports)
nmap_scan_full() {
    _requires nmap || return 1
    _param target --required --positional --help "Target host or IP"
    _param_parse "$@" || return 1

    _exec nmap -T4 -p- "$target" \
        | awk '/^[0-9]+\//{printf "%s\t%s\t%s\n", $1, $2, $3}' \
        | _output_render "port,state,service"
}

# Service and version detection
nmap_scan_services() {
    _requires nmap || return 1
    _param target --required --positional --help "Target host or IP"
    _param ports --help "Port range to scan"
    _param_parse "$@" || return 1

    local cmd=(nmap -sV -sC "$target")
    [[ -n "$ports" ]] && cmd+=(-p "$ports")

    _exec "${cmd[@]}" \
        | awk '/^[0-9]+\//{printf "%s\t%s\t%s\t%s\n", $1, $2, $3, substr($0, index($0,$4))}' \
        | _output_render "port,state,service,version"
}

# OS detection (requires root)
nmap_scan_os() {
    _requires nmap || return 1
    _param target --required --positional --help "Target host or IP"
    _param_parse "$@" || return 1

    _exec sudo nmap -O "$target" \
        | awk '/^(OS|Running|Device|Network)/{
            split($0, a, ":")
            gsub(/^[ \t]+|[ \t]+$/, "", a[1])
            val=""
            for(i=2;i<=length(a);i++){if(i>2)val=val":"; val=val a[i]}
            gsub(/^[ \t]+|[ \t]+$/, "", val)
            print a[1] "\t" val
        }' \
        | _output_render "type,details"
}

# Network discovery (ping sweep)
nmap_scan_discover() {
    _requires nmap || return 1
    _param subnet --required --positional --help "Subnet to scan"
    _param_parse "$@" || return 1

    _exec nmap -sn "$subnet" \
        | awk '/Nmap scan report for/{host=$5} /Host is up/{printf "%s\t%s\n", host, "up"}' \
        | _output_render "host,status"
}

# Stealth SYN scan
nmap_scan_stealth() {
    _requires nmap || return 1
    _param target --required --positional --help "Target host or IP"
    _param ports --help "Port range to scan"
    _param_parse "$@" || return 1

    local cmd=(sudo nmap -sS -T2 "$target")
    [[ -n "$ports" ]] && cmd+=(-p "$ports")

    _exec "${cmd[@]}" \
        | awk '/^[0-9]+\//{printf "%s\t%s\t%s\n", $1, $2, $3}' \
        | _output_render "port,state,service"
}

# UDP scan
nmap_scan_udp() {
    _requires nmap || return 1
    _param target --required --positional --help "Target host or IP"
    _param ports --default "53,67,68,69,123,161,162,500,514,1900" --help "Port range to scan"
    _param_parse "$@" || return 1

    _exec sudo nmap -sU -p "$ports" "$target" \
        | awk '/^[0-9]+\//{printf "%s\t%s\t%s\n", $1, $2, $3}' \
        | _output_render "port,state,service"
}

_nmap_complete_targets() {
    local cur="$1"
    if [[ "$cur" == */* ]]; then
        local base="${cur%%/*}"
        printf '%s\n' "${base}/8" "${base}/16" "${base}/24"
    else
        if [[ -f ~/.targets ]]; then
            cat ~/.targets
        else
            printf '%s\n' "127.0.0.1" "10.0.0.0/24" "192.168.1.0/24"
        fi
    fi
}

# Register completions
_complete_params "nmap_scan_quick" "Quick scan of common ports" "target"
_complete_params "nmap_scan_full" "Full port scan (all 65535 ports)" "target"
_complete_params "nmap_scan_services" "Service and version detection" "target" "ports"
_complete_params "nmap_scan_os" "OS detection (requires root)" "target"
_complete_params "nmap_scan_discover" "Network discovery (ping sweep)" "subnet"
_complete_params "nmap_scan_stealth" "Stealth SYN scan" "target" "ports"
_complete_params "nmap_scan_udp" "UDP scan" "target" "ports"
_complete_func "nmap_scan_quick" "target" _nmap_complete_targets
_complete_func "nmap_scan_full" "target" _nmap_complete_targets
_complete_func "nmap_scan_services" "target" _nmap_complete_targets
_complete_func "nmap_scan_os" "target" _nmap_complete_targets
_complete_func "nmap_scan_discover" "subnet" _nmap_complete_targets
_complete_func "nmap_scan_stealth" "target" _nmap_complete_targets
_complete_func "nmap_scan_udp" "target" _nmap_complete_targets
