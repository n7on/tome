# Output formatting for command results
# Supports: table, json, csv, raw

declare -g _GRIM_OUTPUT_HEADERS=""
declare -g _GRIM_OUTPUT_EXTRACTOR=""
declare -g _GRIM_OUTPUT_TYPE="awk"

# Run a command, piping stdout through while capturing stderr
# On failure, stderr is logged via grim_message_error
# Usage: _grim_command_run "${cmd[@]}" | _grim_command_output_render
#        _grim_command_run --error "Something went wrong" "${cmd[@]}"
_grim_command_run() {
    local custom_error=""
    if [[ "$1" == "--error" ]]; then
        custom_error="$2"
        shift 2
    fi

    if [[ "${dry_run:-}" == "true" ]]; then
        echo "$*"
        return 0
    fi

    local stderr_file
    stderr_file=$(mktemp)

    "$@" 2>"$stderr_file"
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        if [[ -n "$custom_error" ]]; then
            grim_message_error "$custom_error"
        else
            local err
            err=$(grep -m1 . "$stderr_file")
            [[ -n "$err" ]] && grim_message_error "$err"
        fi
    fi

    rm -f "$stderr_file"
    return $rc
}

# Set output headers and extractor for rendering
# Usage: _grim_command_output_set "IP,PORT,STATE,SERVICE" '{print $2, $1, $3, $4}'
#        _grim_command_output_set "name,ip" '.[].name + "\t" + .[].ip' jq
_grim_command_output_set() {
    _GRIM_OUTPUT_HEADERS="$1"
    _GRIM_OUTPUT_EXTRACTOR="$2"
    _GRIM_OUTPUT_TYPE="${3:-awk}"
}

# Format and output data based on selected format
# Usage: echo "$raw_output" | _grim_command_output_render
#        Or: _grim_command_output_render <<< "$raw_output"
_grim_command_output_render() {
    local format="${output_format:-table}"
    local headers="$_GRIM_OUTPUT_HEADERS"
    local extractor="$_GRIM_OUTPUT_EXTRACTOR"
    local type="$_GRIM_OUTPUT_TYPE"

    # Read input
    local input
    input=$(cat)

    # Dry run: pass through raw input
    if [[ "${dry_run:-}" == "true" ]]; then
        echo "$input"
        return 0
    fi

    # Extract data using the configured extractor
    local data
    case "$type" in
        jq)
            _grim_command_requires jq || {
                grim_message_error "jq required for jq extractor"
                return 1
            }
            data=$(echo "$input" | jq -r "$extractor" 2>/dev/null)
            ;;
        awk|*)
            data=$(echo "$input" | awk "$extractor" 2>/dev/null)
            ;;
    esac
    
    case "$format" in
        raw)
            echo "$input"
            ;;
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
