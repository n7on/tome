# Command parameter and completion management
declare -gA _GRIM_COMMAND_COMPLETERS
declare -gA _GRIM_COMMAND_PARAMS
declare -gA _GRIM_COMMAND_FLAGS

# Filter and return completion items for a given prefix
# Usage: _grim_command_filter "sub1 sub2 sub3" "s"
_grim_command_filter() {
    local items="$1"
    local cur="$2"
    compgen -W "$items" -- "$cur"
}

# Check that required commands are available
# Usage: _grim_command_requires jq az curl
_grim_command_requires() {
    local missing=""
    
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+="$cmd "
        fi
    done
    
    if [[ -n "$missing" ]]; then
        _grim_log_error "Required commands not found: ${missing%% }"
        return 1
    fi
}

# Declare parameters and optional defaults for the calling function
# Usage: _grim_command_init env=dev region=us-east-1 subscription
#        Sets env and region with defaults, subscription without default
_grim_command_init() {
    local func="${FUNCNAME[1]}"
    local param
    
    for param in "$@"; do
        if [[ "$param" == *"="* ]]; then
            # Has default value
            local name="${param%%=*}"
            local default="${param#*=}"
            _GRIM_COMMAND_PARAMS["${func}:${name}"]=1
            _GRIM_COMMAND_FLAGS["${func}:${name}"]="$default"
        else
            # No default
            _GRIM_COMMAND_PARAMS["${func}:${param}"]=1
        fi
    done
}

# Set default value for a parameter
# Usage: _grim_command_default env "dev"
#        _grim_command_default region "us-east-1"
_grim_command_default() {
    local func="${FUNCNAME[1]}"
    local param="$1"
    local default_value="$2"
    
    local current="${_GRIM_COMMAND_FLAGS[${func}:${param}]:-}"
    
    # Only apply default if param is empty
    if [[ -z "$current" ]]; then
        _GRIM_COMMAND_FLAGS["${func}:${param}"]="$default_value"
        eval "$param=\"$default_value\""
    fi
}

# Parse command-line arguments into variables
# Usage: _grim_command_parse "$@"
#        Now $foo, $bar, $baz are available as local variables
_grim_command_parse() {
    local func="${FUNCNAME[1]}"
    local -A flags
    local -a args
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --*=*) flags["${1%%=*}"]="${1#*=}" ;;
            --*) flags["$1"]="${2:-true}"; shift ;;
            *) args+=("$1") ;;
        esac
        shift
    done
    
    # Store parsed flags for validation and export to caller's scope
    local exports=""
    for key in "${!_GRIM_COMMAND_PARAMS[@]}"; do
        [[ "$key" == "${func}:"* ]] || continue
        local param_name="${key##*:}"
        local flag_name="--${param_name}"
        # Only update if flag was actually provided, preserving defaults
        [[ -v flags[$flag_name] ]] && _GRIM_COMMAND_FLAGS["${func}:${param_name}"]="${flags[$flag_name]}"
        local value="${_GRIM_COMMAND_FLAGS[${func}:${param_name}]:-}"
        exports+="$param_name=\"$value\"; "
    done
    
    eval "$exports"
}

# Validate a parameter with rules
# Usage: _grim_command_validate sub --required
#        _grim_command_validate env --required --regex "^(dev|prod)$"
_grim_command_validate() {
    local func="${FUNCNAME[1]}"
    local param="$1"
    shift
    
    local value="${_GRIM_COMMAND_FLAGS[${func}:${param}]:-}"
    local required=0
    local regex=""
    local default=""
    
    # Parse validation rules
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --required) required=1 ;;
            --regex) regex="$2"; shift ;;
            --default) default="$2"; shift ;;
        esac
        shift
    done
    
    # Apply default if empty
    if [[ -z "$value" && -n "$default" ]]; then
        value="$default"
        _GRIM_COMMAND_FLAGS["${func}:${param}"]="$value"
        eval "$param=\"$value\""
    fi
    
    # Check required
    if [[ $required -eq 1 && -z "$value" ]]; then
        _grim_log_error "Parameter --$param is required"
        return 1
    fi
    
    # Skip regex validation if empty and not required
    [[ -z "$value" ]] && return 0
    
    # Validate regex if provided
    if [[ -n "$regex" && ! "$value" =~ $regex ]]; then
        _grim_log_error "Parameter --$param does not match pattern: $regex, got: $value"
        return 1
    fi
}

# Set a completer function for a specific parameter
# Usage: _grim_command_set_complete "my_func" "foo" "my_completer_func"
#        _grim_command_set_complete "my_func" "bar"
_grim_command_set_complete() {
    local func="$1"
    local param="$2"
    local completer="$3"
    
    # Convert param name to flag format (foo -> --foo)
    local param_flag="--${param}"
    
    # Register the parameter
    _GRIM_COMMAND_PARAMS["${func}:${param}"]=1
    
    # Register the completer if provided
    if [[ -n "$completer" ]]; then
        _GRIM_COMMAND_COMPLETERS["${func}:${param_flag}"]="$completer"
    fi
    
    # Register completion if not already done
    if ! complete -p "$func" &>/dev/null; then
        complete -o bashdefault -o default -o nospace -F _grim_command_dispatcher_complete "$func"
    fi
}

# Internal dispatcher for all completions
_grim_command_dispatcher_complete() {
    local func="${COMP_WORDS[0]}"
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # If previous word is a flag with a custom completer, use it
    if [[ -v _GRIM_COMMAND_COMPLETERS["${func}:${prev}"] ]]; then
        local completer="${_GRIM_COMMAND_COMPLETERS[${func}:${prev}]}"
        COMPREPLY=($("$completer" "$cur"))
    else
        # Otherwise suggest available parameters as flags
        local flags=""
        for key in "${!_GRIM_COMMAND_PARAMS[@]}"; do
            [[ "$key" == "${func}:"* ]] && flags+=" --${key##*:}"
        done
        COMPREPLY=($(compgen -W "$flags" -- "$cur"))
    fi
}
