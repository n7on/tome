# Command parameter and completion management
declare -gA _GRIM_COMMAND_COMPLETERS
declare -gA _GRIM_COMMAND_COMPLETER_FUNCS
declare -gA _GRIM_COMMAND_PARAMS
declare -gA _GRIM_COMMAND_FLAGS
declare -gA _GRIM_COMMAND_POSITIONAL
declare -gA _GRIM_COMMAND_REQUIRED
declare -gA _GRIM_COMMAND_REGEX
declare -gA _GRIM_COMMAND_PATH
declare -gA _GRIM_COMMAND_HELP
declare -gA _GRIM_COMMAND_DESCRIPTION

# Filter and return completion items for a given prefix
# Usage: _grim_command_complete_filter "sub1 sub2 sub3" "s"
_grim_command_complete_filter() {
    local items="$1"
    local cur="$2"
    compgen -W "$items" -- "$cur"

}

# Check that required commands are available
# Usage: _grim_command_requires jq az curl
_grim_command_requires() {
    if [[ $# -eq 0 ]]; then
        _grim_message_error "_grim_command_requires: no commands specified"
        return 1
    fi

    local missing=""

    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+="$cmd "
        fi
    done

    if [[ -n "$missing" ]]; then
        _grim_message_error "Required commands not found: ${missing%% }"
        return 1
    fi
}

# Run a command array, piping stdout to output_render and capturing stderr as warnings
# Usage: local cmd=(nmap -T4 -p- "$target")
#        _grim_command_run "${cmd[@]}"
_grim_command_run() {
    if [[ $# -eq 0 ]]; then
        _grim_message_error "_grim_command_run: no command specified"
        return 1
    fi

    local stderr_file
    stderr_file=$(mktemp)

    "$@" 2>"$stderr_file" | _grim_command_output_render

    local rc=${PIPESTATUS[0]}

    if [[ -s "$stderr_file" ]]; then
        while IFS= read -r line; do
            _grim_message_warn "$line"
        done < "$stderr_file"
    fi

    rm -f "$stderr_file"
    return "$rc"
}

# Run a command array, capturing stderr as warnings (no output rendering)
# Usage: _grim_command_exec "${cmd[@]}"
_grim_command_exec() {
    if [[ $# -eq 0 ]]; then
        _grim_message_error "_grim_command_exec: no command specified"
        return 1
    fi

    local stderr_file
    stderr_file=$(mktemp)

    "$@" 2>"$stderr_file"

    local rc=$?

    if [[ -s "$stderr_file" ]]; then
        while IFS= read -r line; do
            _grim_message_warn "$line"
        done < "$stderr_file"
    fi

    rm -f "$stderr_file"
    return "$rc"
}

# Set command description for help output
# Usage: _grim_command_description "Quick scan of common ports"
_grim_command_description() {
    local func="${FUNCNAME[1]}"
    _GRIM_COMMAND_DESCRIPTION["$func"]="$1"
}

# Declare a parameter with its options (called inside functions)
# Usage: _grim_command_param target --required --positional --help "Target host or IP"
#        _grim_command_param ports --default "1-1000" --regex "^[0-9,.-]+$" --help "Port range"
#        _grim_command_param input --required --path file --help "Input file"
_grim_command_param() {
    local func="${FUNCNAME[1]}"
    local param="$1"
    shift

    _GRIM_COMMAND_PARAMS["${func}:${param}"]=1
    _GRIM_COMMAND_FLAGS["${func}:${param}"]=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --default) _GRIM_COMMAND_FLAGS["${func}:${param}"]="$2"; shift ;;
            --required) _GRIM_COMMAND_REQUIRED["${func}:${param}"]=1 ;;
            --positional) _GRIM_COMMAND_POSITIONAL["$func"]="$param" ;;
            --regex) _GRIM_COMMAND_REGEX["${func}:${param}"]="$2"; shift ;;
            --path) _GRIM_COMMAND_PATH["${func}:${param}"]="${2:-file}"; shift ;;
            --help) _GRIM_COMMAND_HELP["${func}:${param}"]="$2"; shift ;;
        esac
        shift
    done
}

# Parse command-line arguments, validate, and export as variables
# Usage: _grim_command_param_parse "$@" || return 1
_grim_command_param_parse() {
    local func="${FUNCNAME[1]}"

    local -A flags
    local -a args

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help) _grim_command_show_help "$func"; return 1 ;;
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
    if [[ ${#args[@]} -gt 0 && -v _GRIM_COMMAND_POSITIONAL["$func"] ]]; then
        local pos_param="${_GRIM_COMMAND_POSITIONAL[$func]}"
        local pos_flag="--${pos_param}"
        [[ ! -v flags[$pos_flag] ]] && flags["$pos_flag"]="${args[*]}"
    fi

    # Store parsed flags and export to caller's scope
    local exports=""
    for key in "${!_GRIM_COMMAND_PARAMS[@]}"; do
        [[ "$key" == "${func}:"* ]] || continue
        local param_name="${key##*:}"
        local flag_name="--${param_name}"
        [[ -v flags[$flag_name] ]] && _GRIM_COMMAND_FLAGS["${func}:${param_name}"]="${flags[$flag_name]}"
        local value="${_GRIM_COMMAND_FLAGS[${func}:${param_name}]:-}"
        exports+="$param_name=\"$value\"; "
    done
    eval "$exports"

    # Validate all parameters
    for key in "${!_GRIM_COMMAND_PARAMS[@]}"; do
        [[ "$key" == "${func}:"* ]] || continue
        local param_name="${key##*:}"
        local value="${_GRIM_COMMAND_FLAGS[${func}:${param_name}]:-}"

        if [[ -v _GRIM_COMMAND_REQUIRED["$key"] && -z "$value" ]]; then
            _grim_message_error "Parameter --$param_name is required"
            return 1
        fi

        [[ -z "$value" ]] && continue

        if [[ -v _GRIM_COMMAND_REGEX["$key"] ]]; then
            local regex="${_GRIM_COMMAND_REGEX[$key]}"
            if [[ ! "$value" =~ $regex ]]; then
                _grim_message_error "Parameter --$param_name does not match pattern: $regex, got: $value"
                return 1
            fi
        fi

        if [[ -v _GRIM_COMMAND_PATH["$key"] ]]; then
            local path_type="${_GRIM_COMMAND_PATH[$key]}"
            case "$path_type" in
                file)
                    if [[ ! -f "$value" ]]; then
                        _grim_message_error "Parameter --$param_name: file not found: $value"
                        return 1
                    fi ;;
                dir)
                    if [[ ! -d "$value" ]]; then
                        _grim_message_error "Parameter --$param_name: directory not found: $value"
                        return 1
                    fi ;;
            esac
        fi
    done
}

# Display help for a command
_grim_command_show_help() {
    local func="$1"
    local desc="${_GRIM_COMMAND_DESCRIPTION[$func]:-}"
    local positional="${_GRIM_COMMAND_POSITIONAL[$func]:-}"

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
    for key in "${!_GRIM_COMMAND_PARAMS[@]}"; do
        [[ "$key" == "${func}:"* ]] || continue
        local param="${key##*:}"
        local help="${_GRIM_COMMAND_HELP[${func}:${param}]:-}"
        local default="${_GRIM_COMMAND_FLAGS[${func}:${param}]:-}"

        local hints=()
        [[ -v _GRIM_COMMAND_REQUIRED["${func}:${param}"] ]] && hints+=("required")
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

# Register parameters for completion (called at file scope)
# Automatically includes output_format and help as default parameters
# Usage: _grim_command_complete_params "my_func" "target" "ports"
_grim_command_complete_params() {
    local func="$1"
    shift

    # Default parameters for all commands
    _GRIM_COMMAND_PARAMS["${func}:output_format"]=1
    _GRIM_COMMAND_FLAGS["${func}:output_format"]="table"
    _GRIM_COMMAND_COMPLETERS["${func}:--output_format"]="json table tsv raw"
    _GRIM_COMMAND_PARAMS["${func}:help"]=1

    for param in "$@"; do
        _GRIM_COMMAND_PARAMS["${func}:${param}"]=1
    done

    # Register completion handler
    if ! complete -p "$func" &>/dev/null 2>&1; then
        complete -o bashdefault -o default -o nospace -F _grim_command_complete_dispatch "$func"
    fi
}

# Set static value completions for a parameter (called at file scope)
# Usage: _grim_command_complete_values "my_func" "env" "dev" "staging" "prod"
_grim_command_complete_values() {
    local func="$1"
    local param="$2"
    shift 2
    _GRIM_COMMAND_COMPLETERS["${func}:--${param}"]="$*"
}

# Set a function as completer for a parameter (called at file scope)
# Usage: _grim_command_complete_func "my_func" "target" _my_target_generator
_grim_command_complete_func() {
    local func="$1"
    local param="$2"
    local completer_func="$3"
    _GRIM_COMMAND_COMPLETER_FUNCS["${func}:--${param}"]="$completer_func"
}

# Internal dispatcher for all completions
_grim_command_complete_dispatch() {
    local func="${COMP_WORDS[0]}"
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    # If previous word is a flag, check for function completer first, then static values
    if [[ -v _GRIM_COMMAND_COMPLETER_FUNCS["${func}:${prev}"] ]]; then
        local completer="${_GRIM_COMMAND_COMPLETER_FUNCS[${func}:${prev}]}"
        local values
        values=$("$completer" "$cur")
        local IFS=$'\n'
        COMPREPLY=($(compgen -W "$values" -- "$cur"))
    elif [[ -v _GRIM_COMMAND_COMPLETERS["${func}:${prev}"] ]]; then
        local values="${_GRIM_COMMAND_COMPLETERS[${func}:${prev}]}"
        COMPREPLY=($(compgen -W "$values" -- "$cur"))
    else
        # Collect flags already used on the command line
        local -A used_flags
        for word in "${COMP_WORDS[@]}"; do
            [[ "$word" == --* ]] && used_flags["$word"]=1
        done

        # Suggest available parameters as flags, excluding already used ones
        local flags=""
        for key in "${!_GRIM_COMMAND_PARAMS[@]}"; do
            [[ "$key" == "${func}:"* ]] || continue
            local flag="--${key##*:}"
            [[ -v used_flags["$flag"] ]] || flags+=" $flag"
        done
        COMPREPLY=($(compgen -W "$flags" -- "$cur"))
    fi
}
