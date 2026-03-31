
_azure_graph_queries_dir="$(dirname "${BASH_SOURCE[0]}")/queries/graph"
_azure_graph_user_queries_dir="$HOME/.grim/queries/azure/graph"

_azure_graph_get_query_names() {
    local -A seen
    local names=()
    local dir file name

    for dir in "$_azure_graph_user_queries_dir" "$_azure_graph_queries_dir"; do
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

_azure_graph_load_query() {
    local name="$1"
    local dir file

    for dir in "$_azure_graph_user_queries_dir" "$_azure_graph_queries_dir"; do
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

azure_graph_query() {
    _grim_command_requires az jq || return 1
    _grim_command_description "Query Azure Resource Graph using a saved KQL file"
    _grim_command_param name          --required --positional --help "Query name (from queries/graph/)"
    _grim_command_param subscriptions --help "Comma-separated list of subscription IDs to scope the query"
    _grim_command_param_parse "$@" || return 1

    local kql
    kql=$(_azure_graph_load_query "$name") || return 1

    local cmd=(az graph query -q "$kql" --output json)
    if [[ -n "$subscriptions" ]]; then
        IFS=',' read -ra subs <<< "$subscriptions"
        cmd+=(--subscriptions "${subs[@]}")
    fi

    local result
    result=$("${cmd[@]}" 2>/dev/null) || { _grim_message_error "Graph query failed"; return 1; }

    _grim_command_output_set "NAME,RESOURCE_GROUP,LOCATION,KIND,SUBSCRIPTION_ID" \
        '.data[] | [.name, .resourceGroup, .location, (.kind // "-"), .subscriptionId] | @tsv' jq

    echo "$result" | _grim_command_output_render
}

# Register completions
_grim_command_complete_params "azure_graph_query" "name" "subscriptions"
_grim_command_complete_func "azure_graph_query" "name" _azure_graph_get_query_names
