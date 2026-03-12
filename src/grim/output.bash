# Output formatting for command results
# Supports: table, json, csv

declare -g _GRIM_OUTPUT_HEADERS=""
declare -g _GRIM_OUTPUT_AWK=""

# Run a command, piping stdout through while capturing stderr
# On failure, stderr is logged via grim_message_error
# Usage: _grim_command_run "${cmd[@]}" | _grim_command_output_render
_grim_command_run() {
    if [[ "${dry_run:-}" == "true" ]]; then
        echo "$*"
        return 0
    fi

    local stderr_file
    stderr_file=$(mktemp)

    "$@" 2>"$stderr_file"
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        local err
        err=$(<"$stderr_file")
        [[ -n "$err" ]] && grim_message_error "$err"
    fi

    rm -f "$stderr_file"
    return $rc
}

# Set output headers and awk pattern for extraction
# Usage: _grim_command_output_set "IP,PORT,STATE,SERVICE" '{print $2, $1, $3, $4}'
_grim_command_output_set() {
    _GRIM_OUTPUT_HEADERS="$1"
    _GRIM_OUTPUT_AWK="$2"
}

# Format and output data based on selected format
# Usage: echo "$raw_output" | _grim_command_output_render
#        Or: _grim_command_output_render <<< "$raw_output"
_grim_command_output_render() {
    local format="${output_format:-table}"
    local headers="$_GRIM_OUTPUT_HEADERS"
    local awk_pattern="$_GRIM_OUTPUT_AWK"
    
    # Read input
    local input
    input=$(cat)

    # Dry run: pass through raw input
    if [[ "${dry_run:-}" == "true" ]]; then
        echo "$input"
        return 0
    fi
    
    # Extract data using awk
    local data
    data=$(echo "$input" | awk "$awk_pattern" 2>/dev/null)
    
    case "$format" in
        json)
            _grim_command_output_json "$headers" "$data"
            ;;
        csv)
            _grim_command_output_csv "$headers" "$data"
            ;;
        table|*)
            _grim_command_output_table "$headers" "$data"
            ;;
    esac
}

# Output as JSON array
_grim_command_output_json() {
    local headers="$1"
    local data="$2"
    
    _grim_command_requires jq || {
        grim_message_error "jq required for JSON output"
        return 1
    }
    
    # Split headers into array
    IFS=',' read -ra header_arr <<< "$headers"
    
    # Build JSON
    local json="["
    local first_row=true
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        # Split line into fields (tab-delimited if tabs present, else spaces)
        if [[ "$line" == *$'\t'* ]]; then
            IFS=$'\t' read -ra fields <<< "$line"
        else
            read -ra fields <<< "$line"
        fi
        
        $first_row || json+=","
        first_row=false
        
        json+="{"
        local first_field=true
        for i in "${!header_arr[@]}"; do
            $first_field || json+=","
            first_field=false
            local key="${header_arr[$i]}"
            local value="${fields[$i]:-}"
            # Escape quotes in value
            value="${value//\"/\\\"}"
            json+="\"$key\":\"$value\""
        done
        json+="}"
    done <<< "$data"
    
    json+="]"
    
    echo "$json" | jq .
}

# Output as CSV
_grim_command_output_csv() {
    local headers="$1"
    local data="$2"
    
    # Print headers
    echo "$headers"
    
    # Print data rows
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" == *$'\t'* ]]; then
            # Tab-delimited: replace tabs with commas
            echo "${line//$'\t'/,}"
        else
            echo "$line" | awk '{for(i=1;i<=NF;i++) printf "%s%s", $i, (i<NF?",":"\n")}'
        fi
    done <<< "$data"
}

# Output as formatted table
_grim_command_output_table() {
    local headers="$1"
    local data="$2"
    
    # Combine headers and data for column formatting
    {
        echo "${headers//,/$'\t'}"
        echo "$data"
    } | column -t -s $'\t'
}
