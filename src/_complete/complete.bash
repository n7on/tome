# Completion registration for rig commands
declare -gA _COMPLETERS
declare -gA _COMPLETER_FUNCS
declare -gA _PARAMS
declare -gA _FLAGS
declare -gA _POSITIONAL
declare -gA _REQUIRED
declare -gA _REGEX
declare -gA _PATH
declare -gA _HELP
declare -gA _DESCRIPTION
declare -gA _DEFAULTS
declare -gA _COMPLETE_TYPE

# Filter and return completion items for a given prefix
# Usage: _complete_filter "sub1 sub2 sub3" "s"
_complete_filter() {
    local items="$1"
    local cur="$2"
    compgen -W "$items" -- "$cur"
}

# Register command type (called at file scope, before _complete_params)
# Usage: _complete_type "my_func" query|action
_complete_type() {
    local func="$1"
    local type="$2"
    case "$type" in
        query|action) _COMPLETE_TYPE["$func"]="$type" ;;
        *) echo "_complete_type: invalid type '$type' (must be query or action)" >&2; return 1 ;;
    esac
}

# Register parameters for completion (called at file scope)
# Usage: _complete_params "my_func" "param1" "param2"
_complete_params() {
    local func="$1"
    shift 1

    local type="${_COMPLETE_TYPE[$func]:-query}"

    if [[ "$type" == "query" ]]; then
        _PARAMS["${func}:output"]=1
        _FLAGS["${func}:output"]="table"
        _DEFAULTS["${func}:output"]="table"
        _COMPLETERS["${func}:--output"]="table json tsv md raw"
        _PARAMS["${func}:cache"]=1
        _HELP["${func}:cache"]="Cache TTL in seconds (0 to disable)"
        _PARAMS["${func}:filter"]=1
        _HELP["${func}:filter"]="Filter rows (COLUMN=value, supports wildcards)"
        _PARAMS["${func}:sort"]=1
        _HELP["${func}:sort"]="Sort by column (prefix with - for descending)"
        _PARAMS["${func}:select"]=1
        _HELP["${func}:select"]="Comma-separated list of columns to include"
        _PARAMS["${func}:limit"]=1
        _HELP["${func}:limit"]="Limit output to first N rows"
    fi

    _PARAMS["${func}:debug"]=1
    _HELP["${func}:debug"]="Show verbose error output from external commands"
    _PARAMS["${func}:help"]=1

    for param in "$@"; do
        _PARAMS["${func}:${param}"]=1
    done
}

# Register static value completions for a parameter (called at file scope)
# Usage: _complete_values "my_func" "param" "val1" "val2"
_complete_values() {
    local func="$1"
    local param="$2"
    shift 2
    _COMPLETERS["${func}:--${param}"]="$*"
}

# Register a function as completer for a parameter (called at file scope)
# Usage: _complete_func "my_func" "param" _my_generator
_complete_func() {
    local func="$1"
    local param="$2"
    local completer_func="$3"
    _COMPLETER_FUNCS["${func}:--${param}"]="$completer_func"
}
