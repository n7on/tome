
_azure_law_queries_dir="$(dirname "${BASH_SOURCE[0]}")/kql/law"
_azure_law_user_queries_dir="$HOME/.grim/kql/azure/law"

_azure_law_get_query_names() {
    local -A seen
    local names=()
    local dir file name

    for dir in "$_azure_law_user_queries_dir" "$_azure_law_queries_dir"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r file; do
            name="${file%.kql}"
            [[ -n "${seen[$name]}" ]] && continue
            seen[$name]=1
            names+=("$name")
        done < <(find "$dir" -name "*.kql" -printf "%P\n" 2>/dev/null)
    done

    _grim_command_complete_filter "${names[*]}" "$1"
}

_azure_law_get_workspaces() {
    local workspaces
    workspaces=$(_grim_cache_wrap 300 az monitor log-analytics workspace list --query "[].name" -o tsv 2>/dev/null)
    _grim_command_complete_filter "$workspaces" "$1"
}

_azure_law_load_query() {
    local name="$1"
    local dir file

    for dir in "$_azure_law_user_queries_dir" "$_azure_law_queries_dir"; do
        [[ -d "$dir" ]] || continue
        file="$dir/${name}.kql"
        if [[ -f "$file" ]]; then
            cat "$file"
            return 0
        fi
    done

    _grim_message_error "Query '$name' not found"
    return 1
}

azure_law_query() {
    _grim_command_requires az jq || return 1
    _grim_command_requires_az_extension log-analytics || return 1
    _grim_command_description "Query Azure Log Analytics workspace using a saved KQL file"
    _grim_command_param name      --required --positional --help "Query name (from queries/law/)"
    _grim_command_param workspace --required --help "Log Analytics workspace name or ID"
    _grim_command_param timespan  --default "PT1H" --help "Query timespan as ISO 8601 duration"
    _grim_command_param_parse "$@" || return 1

    local kql
    kql=$(_azure_law_load_query "$name") || return 1

    # Resolve workspace name to customer ID (GUID)
    local workspace_id
    workspace_id=$(_grim_command_exec az monitor log-analytics workspace list \
        --query "[?name=='$workspace'].customerId | [0]" -o tsv)
    if [[ -z "$workspace_id" ]]; then
        _grim_message_error "Workspace '$workspace' not found"
        return 1
    fi

    local result
    result=$(_grim_command_exec az monitor log-analytics query \
        --workspace "$workspace_id" \
        --analytics-query "$kql" \
        --timespan "$timespan" \
        --output json) || { _grim_message_error "Log Analytics query failed"; return 1; }

    local columns rows
    if jq -e 'type == "array"' <<< "$result" &>/dev/null; then
        # New az CLI format: array of objects
        if jq -e 'length == 0' <<< "$result" &>/dev/null; then
            _grim_message_warn "No results found"
            return 0
        fi
        local keys
        keys=$(jq -c '[.[0] | keys_unsorted[]]' <<< "$result")
        columns=$(jq -r '[.[0] | keys_unsorted[] | ascii_upcase] | join(",")' <<< "$result")
        rows=$(jq -r --argjson keys "$keys" '.[] | [.[$keys[]]] | map(. // "" | tostring) | @tsv' <<< "$result")
    else
        # Old format: tables structure
        columns=$(jq -r '[.tables[0].columns[].name | ascii_upcase] | join(",")' <<< "$result")
        rows=$(jq -r '.tables[0].rows[] | map(. // "" | tostring) | @tsv' <<< "$result")
    fi

    echo "$rows" | _grim_command_output_render "$columns"
}

# Register completions
_grim_command_complete_params "azure_law_query" "name" "workspace" "timespan"
_grim_command_complete_values "azure_law_query" "timespan" "PT1H" "PT6H" "PT12H" "P1D" "P3D" "P7D" "P14D" "P30D"
_grim_command_complete_func "azure_law_query" "name" _azure_law_get_query_names
_grim_command_complete_func "azure_law_query" "workspace" _azure_law_get_workspaces
