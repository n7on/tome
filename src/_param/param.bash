# Parameter declaration, parsing, and help display

# Set command description for help output
# Usage: _description "Quick scan of common ports"
_description() {
    local func="${FUNCNAME[1]}"
    _DESCRIPTION["$func"]="$1"
}

# Declare a parameter with its options (called inside functions)
# Usage: _param target --required --positional --help "Target host or IP"
#        _param ports --default "1-1000" --regex "^[0-9,.-]+$" --help "Port range"
#        _param input --required --path file --help "Input file"
_param() {
    local func="${FUNCNAME[1]}"
    local param="$1"
    shift

    _PARAMS["${func}:${param}"]=1
    _FLAGS["${func}:${param}"]=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --default) _FLAGS["${func}:${param}"]="$2"; _DEFAULTS["${func}:${param}"]="$2"; shift ;;
            --required) _REQUIRED["${func}:${param}"]=1 ;;
            --positional) _POSITIONAL["$func"]="$param" ;;
            --regex) _REGEX["${func}:${param}"]="$2"; shift ;;
            --path) _PATH["${func}:${param}"]="${2:-file}"; shift ;;
            --help) _HELP["${func}:${param}"]="$2"; shift ;;
        esac
        shift
    done
}

# Parse command-line arguments, validate, and export as variables
# Usage: _param_parse "$@" || return 1
_param_parse() {
    local func="${FUNCNAME[1]}"

    local -A flags
    local -a args

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help) _show_help "$func"; return 1 ;;
            --*=*) flags["${1%%=*}"]="${1#*=}" ;;
            --*)
                if [[ -n "${2:-}" && "${2:-}" != --* ]]; then
                    flags["$1"]="${2}"; shift
                else
                    flags["$1"]="true"
                fi
                ;;
            *) args+=("$1") ;;
        esac
        shift
    done

    # Assign positional args to the registered positional parameter
    if [[ ${#args[@]} -gt 0 && -v _POSITIONAL["$func"] ]]; then
        local pos_param="${_POSITIONAL[$func]}"
        local pos_flag="--${pos_param}"
        [[ ! -v flags[$pos_flag] ]] && flags["$pos_flag"]="${args[*]}"
    fi

    # Store parsed flags and export to caller's scope
    # Reset all flags first to avoid stale values from previous calls
    local _exports=""
    for _key in "${!_PARAMS[@]}"; do
        [[ "$_key" == "${func}:"* ]] || continue
        local _pname="${_key##*:}"
        local _fname="--${_pname}"
        if [[ -v flags[$_fname] ]]; then
            _FLAGS["${func}:${_pname}"]="${flags[$_fname]}"
        else
            _FLAGS["${func}:${_pname}"]="${_DEFAULTS[${func}:${_pname}]:-}"
        fi
        local _val="${_FLAGS[${func}:${_pname}]:-}"
        _exports+="$_pname='${_val//\'/\'\\\'\'}'; "
    done
    eval "$_exports"

    # Validate all parameters
    for _key in "${!_PARAMS[@]}"; do
        [[ "$_key" == "${func}:"* ]] || continue
        local _pname="${_key##*:}"
        local _val="${_FLAGS[${func}:${_pname}]:-}"

        if [[ -v _REQUIRED["$_key"] && -z "$_val" ]]; then
            _message_error "Parameter --$_pname is required"
            return 1
        fi

        [[ -z "$_val" ]] && continue

        if [[ -v _REGEX["$_key"] ]]; then
            local _regex="${_REGEX[$_key]}"
            if [[ ! "$_val" =~ $_regex ]]; then
                _message_error "Parameter --$_pname does not match pattern: $_regex, got: $_val"
                return 1
            fi
        fi

        if [[ -v _PATH["$_key"] ]]; then
            local _path_type="${_PATH[$_key]}"
            case "$_path_type" in
                file)
                    if [[ ! -f "$_val" ]]; then
                        _message_error "Parameter --$_pname: file not found: $_val"
                        return 1
                    fi ;;
                dir)
                    if [[ ! -d "$_val" ]]; then
                        _message_error "Parameter --$_pname: directory not found: $_val"
                        return 1
                    fi ;;
            esac
        fi
    done
}

# Display help for a command
_show_help() {
    local func="$1"
    local desc="${_DESCRIPTION[$func]:-}"
    local positional="${_POSITIONAL[$func]:-}"

    # Header
    if [[ -n "$desc" ]]; then
        echo "$func - $desc"
    else
        echo "$func"
    fi
    echo

    # Usage
    if [[ -n "$positional" ]]; then
        echo "Usage: $func [$positional] [OPTIONS]"
    else
        echo "Usage: $func [OPTIONS]"
    fi
    echo

    # Parameters
    echo "Parameters:"
    for key in "${!_PARAMS[@]}"; do
        [[ "$key" == "${func}:"* ]] || continue
        local param="${key##*:}"
        local help="${_HELP[${func}:${param}]:-}"
        local default="${_FLAGS[${func}:${param}]:-}"

        local hints=()
        [[ -v _REQUIRED["${func}:${param}"] ]] && hints+=("required")
        [[ "$positional" == "$param" ]] && hints+=("positional")
        [[ -n "$default" ]] && hints+=("default: $default")

        local meta=""
        if [[ ${#hints[@]} -gt 0 ]]; then
            local IFS=", "
            meta=" (${hints[*]})"
        fi

        if [[ -n "$help" ]]; then
            printf "  --%-20s %s%s\n" "$param" "$help" "$meta"
        else
            printf "  --%-20s%s\n" "$param" "$meta"
        fi
    done
}
