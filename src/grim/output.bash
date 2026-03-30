# Output formatting for command results
# Supports: table, json, tsv, raw

declare -g _GRIM_OUTPUT_HEADERS=""
declare -g _GRIM_OUTPUT_EXTRACTOR=""
declare -g _GRIM_OUTPUT_TYPE="awk"

# Set output headers and extractor for rendering
# Usage: _grim_command_output_set "IP,PORT,STATE,SERVICE" '{print $2, $1, $3, $4}'
#        _grim_command_output_set "name,ip" '.[].name + "\t" + .[].ip' jq
_grim_command_output_set() {
    _GRIM_OUTPUT_HEADERS="$1"
    _GRIM_OUTPUT_EXTRACTOR="$2"
    _GRIM_OUTPUT_TYPE="${3:-awk}"

    case "$_GRIM_OUTPUT_TYPE" in
        awk|jq) ;;
        *) _grim_message_error "Invalid output type: $_GRIM_OUTPUT_TYPE (expected: awk, jq)"; return 1 ;;
    esac
}

# Format and output data based on selected format
# Usage: echo "$raw_output" | _grim_command_output_render
#        Or: _grim_command_output_render <<< "$raw_output"
_grim_command_output_render() {
    local format="${output_format:-table}"
    local headers="$_GRIM_OUTPUT_HEADERS"
    local extractor="$_GRIM_OUTPUT_EXTRACTOR"
    local type="$_GRIM_OUTPUT_TYPE"

    case "$format" in
        raw|json|tsv|table) ;;
        *) _grim_message_error "Invalid output format: $format (expected: raw, json, tsv, table)"; return 1 ;;
    esac

    # Read input
    local input
    input=$(cat)

    # Extract data using the configured extractor
    local data
    case "$type" in
        jq)
            _grim_command_requires jq || {
                _grim_message_error "jq required for jq extractor"
                return 1
            }
            data=$(echo "$input" | jq -r "$extractor" 2>/dev/null)
            ;;
        awk)
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
        tsv)
            _grim_command_output_tsv "$headers" "$data"
            ;;
        table)
            _grim_command_output_table "$headers" "$data"
            ;;
    esac
}

# Output as JSON array
_grim_command_output_json() {
    local headers="$1"
    local data="$2"
    
    _grim_command_requires jq || {
        _grim_message_error "jq required for JSON output"
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

# Output as TSV
_grim_command_output_tsv() {
    local headers="$1"
    local data="$2"

    echo "${headers//,/$'\t'}"
    echo "$data"
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
